# frozen_string_literal: true

require 'erb'
require 'fileutils'
require 'active_support'
require_relative 'fixtures/daily_report_incident_policy'

# Load the production renderer, without loading Rails, models or a database.
backend = ENV.fetch('VPSADMIN_RENDER_SOURCE')
module VpsAdmin
  module API; end
end
require File.join(backend, 'api/lib/vpsadmin/api/time_zones')
builder_path = File.join(backend, 'api/models/mail_template_translation.rb')
builder = File.read(builder_path)[/^  class TemplateBuilder\n.*?^  end/m]
raise 'Production TemplateBuilder was not found' unless builder

module MailTemplateTranslation; end
MailTemplateTranslation.module_eval(builder, builder_path, 12)

RSpec.describe 'Site daily incident-policy summary' do
  let(:source) { File.read(File.expand_path('../templates/daily_report/email/en.html.erb', __dir__)) }

  # Only unrelated legacy sections use relation-shaped objects. Empty stand-ins
  # keep this full-template render independent of Rails and database queries.
  class EmptyReportRows < Array
    def load = self
    def includes(*) = self
    def sum(*) = 0
  end

  def legacy_vars
    empty = -> { EmptyReportRows.new }
    states = -> { %i[new active suspended soft_deleted hard_deleted].to_h { |key| [key, { all: empty.call, changed: empty.call }] } }
    {
      base_url: DailyReportIncidentPolicyFixture::BASE_URL,
      date: { start: DailyReportIncidentPolicyFixture::AS_OF - 86_400, end: DailyReportIncidentPolicyFixture::AS_OF },
      users: states.call, vps: states.call,
      datasets: { all: empty.call, hypervisor: {}, primary: {}, backup: {} },
      snapshots: { new: empty.call, all: empty.call, hypervisor: {}, primary: {}, backup: {} },
      downloads: %i[new all hypervisor primary backup].to_h { |key| [key, empty.call] },
      chains: %i[total done failed fatal resolved all_failed].to_h { |key| [key, empty.call] },
      transactions: %i[total done pending successful warning rolledback failed].to_h { |key| [key, empty.call] },
      backups: %i[old_latest_any_snapshot old_latest_backup_snapshot too_many_in_hypervisor too_many_in_backup].to_h { |key| [key, empty.call] },
      dataset_expansions: %i[active new resolved].to_h { |key| [key, empty.call] },
      incident_reports: { new: empty.call },
      oom_reports: %i[by_vps preventions by_node by_killed_name].to_h { |key| [key, empty.call] },
      dns_zones: { new: empty.call }, dns_record_logs: empty.call,
      payments: %i[queued unmatched processed ignored accepted incoming].to_h { |key| [key, empty.call] },
      cluster_resources: { overused: empty.call }
    }
  end

  def render_payload(payload)
    vars = legacy_vars
    vars[:incident_policy_summary] = payload unless payload.nil?
    MailTemplateTranslation::TemplateBuilder.new(vars, time_zone: 'UTC').build(source)
  end

  def section(html)
    html[/<section id="incident-policy-summary".*?<\/section>/m]
  end

  it 'retains the legacy report when an older producer omits the payload' do
    html = render_payload(nil)
    expect(section(html)).to be_nil
    expect(html).to include('Daily report', 'Incident reports', 'OOM reports', 'Payments', 'Cluster resources over limit')
  end

  it 'describes present empty data without empty tables or empty subsection headings' do
    html = section(render_payload(DailyReportIncidentPolicyFixture.empty))
    expect(html).to include('No current incident policy matches.', 'No recorded policy activity', 'No outstanding policy actions')
    expect(html).not_to match(/<table\b|<h3>/)
  end

  it 'keeps current counts separate from saved facts and preserves null/false distinctions' do
    html = section(render_payload(DailyReportIncidentPolicyFixture.full))
    expect(html).to include('2 / 3 in 7 days', 'Reports remaining: 1', '4 / — in 7 days', 'Invalid configuration.')
    expect(html).to include('Mode: —', 'Owner inactive.', 'Ownership transfer pending.', 'Matched: unknown')
    expect(html).to include('2026-11-24 09:00:00 UTC', '2026-11-23 09:00:00 UTC', 'up to, but not including, the end time')
    expect(html).to include('Warning emails allowed: yes', 'automatic shutdown allowed: unknown')
    expect(html).not_to include('Settings valid: true', 'Owner active: true', 'transfer pending: false', 'cooldown ends: —')
    zero_remaining = DailyReportIncidentPolicyFixture.empty.merge(
      overview: DailyReportIncidentPolicyFixture.collection([
        DailyReportIncidentPolicyFixture.exposure(count_7d: 3, warning_remaining: 0, status: 'warning')
      ])
    )
    expect(section(render_payload(zero_remaining))).to include('Reports remaining: 0', '3 / 3 in 7 days')
    disabled = DailyReportIncidentPolicyFixture.empty.merge(
      overview: DailyReportIncidentPolicyFixture.collection([
        DailyReportIncidentPolicyFixture.exposure(warning_permitted: false, stop_enforced: false)
      ])
    )
    expect(section(render_payload(disabled))).to include('Warning emails allowed: no; automatic shutdown allowed: no')
    no_action = DailyReportIncidentPolicyFixture.empty.merge(
      overview: DailyReportIncidentPolicyFixture.collection([
        DailyReportIncidentPolicyFixture.exposure(latest_action_id: nil, next_warning_allowed_at: nil)
      ]),
      activity: DailyReportIncidentPolicyFixture.collection([
        DailyReportIncidentPolicyFixture.history(
          action_id: nil, decision: 'none', activity_at: DailyReportIncidentPolicyFixture::AS_OF - 7200,
          activity_basis: 'evaluation', mail_state: nil, stop_completed_at: nil,
          physical_stop_action_id: nil, transaction_chain_id: nil, notice_report_id: nil
        )
      ])
    )
    absent = section(render_payload(no_action))
    expect(absent.scan('No recorded action.').length).to eq(2)
    expect(absent).to include('decision: No action')
    expect(absent).not_to include('cooldown ends:', 'Confirmed shutdown:', 'Accepted by mail server')
  end

  it 'distinguishes a confirmed shared stop from its failed, queued or suppressed mail' do
    html = section(render_payload(DailyReportIncidentPolicyFixture.full))
    expect(html).to include('Confirmed shutdown: 2026-11-24 08:00:00 UTC', 'Mail: Failed', 'Mail: Queued', 'Mail: Suppressed')
    expect(html).to include('Accepted by mail server', 'Mail: Uncertain', 'Shared shutdown action #22', 'share one VPS shutdown')
    expect(html).to include('Failed or uncertain outcome last updated', 'Evaluation: 2026-11-22 09:00:00 UTC')
    expect(html).not_to include('since the previous successful report', 'Mail: sent')
    rows = html.scan(/<tr>.*?<\/tr>/m)
    confirmed = rows.find { |row| row.include?('Evaluation #200:') }
    expect(confirmed).to include('Mail: Failed', 'Confirmed shutdown: 2026-11-24 08:00:00 UTC')
    suppressed = rows.find { |row| row.include?('Evaluation #203:') }
    expect(suppressed).to include('Mail: Suppressed')
    expect(suppressed).not_to include('Confirmed shutdown:')
    expect(suppressed).not_to include('Accepted by mail server')
  end

  it 'shows explicit cap accounting for every capped collection' do
    html = section(render_payload(DailyReportIncidentPolicyFixture.capped))
    expect(html.scan('Showing 25 of 28; 3 omitted.').length).to eq(3)
    expect(html.scan('<tr>').length).to eq(78)
  end

  it 'renders null links as text and does not invent missing historical identities' do
    html = section(render_payload(DailyReportIncidentPolicyFixture.null_links))
    expect(html).not_to include('<a ', 'href=')
    expect(html).to include('Unavailable', 'Report #300')
    expect(html).not_to include('href=""')
  end

  it 'escapes every hostile string and link attribute in the new summary' do
    html = section(render_payload(DailyReportIncidentPolicyFixture.hostile))
    expect(html).to include('&lt;script&gt;hostile &amp; &quot;value&quot;&lt;/script&gt;')
    expect(html).to include('q=&quot;&lt;row&gt;&quot;&amp;next=1', 'q=&quot;&lt;collection&gt;&quot;&amp;next=1')
    expect(html).not_to include('<script>', '<row>', '<collection>')
  end

  it 'preserves the surrounding report sections across all payload variants' do
    baseline = render_payload(nil).gsub(/\s+/, ' ')
    DailyReportIncidentPolicyFixture.variants.each_value do |payload|
      html = render_payload(payload).sub(/<section id="incident-policy-summary".*?<\/section>/m, '').gsub(/\s+/, ' ')
      expect(html).to eq(baseline)
    end
  end

  it 'writes the exact full-template synthetic previews when requested' do
    directory = ENV['DAILY_REPORT_PREVIEWS']
    next unless directory

    FileUtils.mkdir_p(directory)
    DailyReportIncidentPolicyFixture.variants.each do |name, payload|
      File.write(File.join(directory, "daily-report-#{name}.html"), render_payload(payload))
    end
  end
end
