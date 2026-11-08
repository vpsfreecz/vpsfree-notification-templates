# frozen_string_literal: true

require 'erb'
require 'fileutils'

class DnsMonitoringPreview
  User = Struct.new(:login)
  Server = Struct.new(:name)
  ServerZone = Struct.new(:dns_server)
  Primary = Struct.new(:id, :ip_addr)
  Path = Struct.new(:dns_zone_transfer, :dns_server_zone, :secondary_source_addr, :failed_since, :reason_code, :reason)
  Zone = Struct.new(:id, :name, :alert_eligible_primary_transfer_states)
  Event = Struct.new(:id, :action_state)

  def initialize(marker, reason)
    primary = Primary.new(21, '192.0.2.10')
    path = Path.new(primary, ServerZone.new(Server.new('ns.example.test')), '192.0.2.20',
                    Time.utc(2026, 11, 8, 12), 'refused', 'Transfer refused')
    @object = Zone.new(7, 'example.test.', [path])
    @user = User.new('example-user')
    @event = Event.new(42, marker => reason)
    @base_url = 'https://admin.example.test/'
  end

  def local_time(value, format)
    value.utc.strftime(format)
  end

  def render(path)
    ERB.new(File.read(path), trim_mode: '-').result(binding)
  end
end

root = File.expand_path('../templates', __dir__)
output = ARGV.shift
abort 'usage: ruby test/dns_monitoring_templates.rb [PREVIEW_DIRECTORY]' unless ARGV.empty?
FileUtils.mkdir_p(output) if output

cases = {
  'dns_primary_transfer_failure_confirmed' => [[nil, nil]],
  'dns_primary_transfer_failure_closed' => [
    ['dns_primary_transfer_closure_reason', 'recovered'],
    ['dns_primary_transfer_closure_reason', 'configuration_changed']
  ],
  'dns_secondary_missing_primary_confirmed' => [[nil, nil]],
  'dns_secondary_missing_primary_closed' => [
    ['dns_secondary_missing_primary_closure_reason', 'configuration_restored'],
    ['dns_secondary_missing_primary_closure_reason', 'configuration_changed']
  ]
}
notices = {
  'en' => '(This is an automated mail from vpsAdmin, your reply will be sent to our support)',
  'cs' => '(Tento mail automaticky rozesílá vpsAdmin, Tvoje odpověď se zašle na naši podporu)'
}

rendered = 0
cases.each do |name, variants|
  variants.each do |marker, reason|
    %w[en cs].each do |language|
      preview = DnsMonitoringPreview.new(marker, reason)
      directory = File.join(root, "alert_user_#{name}", 'email')
      subject = preview.render(File.join(directory, "#{language}.subject.erb"))
      body = preview.render(File.join(directory, "#{language}.text.erb"))
      raise "missing subject prefix: #{name}" unless subject.start_with?('[vpsFree.cz] DNS ')
      raise "unrendered expression: #{name}" if (subject + body).include?('<%')
      raise "missing exact notice: #{name}" unless body.lines.last.strip == notices.fetch(language)
      raise "wrong zone scope: #{name}" unless (subject + body).include?('example.test.')

      if name.end_with?('confirmed')
        raise "missing incident acknowledgement: #{name}" unless body.include?('action=ack&id=42')
      else
        raise "missing zone link: #{name}" unless body.include?('action=zone_show&id=7')
      end

      if name == 'dns_primary_transfer_failure_confirmed'
        raise 'missing failed primary path' unless body.include?('192.0.2.10') && body.include?('192.0.2.20')
        raise 'missing refusal diagnostic' unless body.include?('refused') && body.include?('Transfer refused')
        raise 'missing path-specific activity link' unless body.include?('dns_zone=7&dns_zone_transfer=21')
      elsif name == 'dns_primary_transfer_failure_closed'
        expected_subject = if reason == 'recovered'
                             language == 'en' ? 'primary transfer checks passed' : 'kontroly primárních serverů uspěly'
                           else
                             language == 'en' ? 'transfer configuration changed' : 'změna konfigurace přenosu'
                           end
        raise "wrong closure branch: #{language}/#{reason}" unless subject.include?(expected_subject)
        if reason == 'configuration_changed'
          disclaimer = language == 'en' ? 'does not confirm' : 'nepotvrzuje'
          raise 'configuration removal claims recovery' unless body.include?(disclaimer)
        end
      elsif name == 'dns_secondary_missing_primary_closed'
        expected = if reason == 'configuration_restored'
                     language == 'en' ? 'Transfer readiness remains pending' : 'Samotné obnovení'
                   else
                     language == 'en' ? 'no longer enabled' : 'už není zapnutá'
                   end
        raise "wrong configuration closure: #{language}/#{reason}" unless body.include?(expected)
      end

      if output
        filename = "#{language}-#{name}-#{reason || 'confirmed'}.txt"
        File.write(File.join(output, filename), "Subject: #{subject.strip}\n\n#{body}")
      end
      rendered += 1
    end
  end
end

puts "Rendered #{rendered} DNS mail variants with distinct recovery/configuration branches"
