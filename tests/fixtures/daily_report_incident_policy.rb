# frozen_string_literal: true

# Shared by standalone site rendering and the backend daily-report spec.
module DailyReportIncidentPolicyFixture
  AS_OF = Time.utc(2026, 11, 24, 9, 0, 0)
  BASE_URL = 'https://vpsadmin.example.test/'

  module_function

  def exposure(**changes)
    row = {
      id: '123:oomd', vps_id: 123, user_id: 42, node_id: 5,
      hostname: 'sample.example.test', user_login: 'sample-owner', node_name: 'node.example.test',
      policy_key: 'oomd', label: 'Memory pressure', owner_active: true, transfer_pending: false,
      count_7d: 2, count_30d: 3, warning_period_days: 7, stop_period_days: 30,
      warning_limit: 3, stop_limit: 10, warning_remaining: 1, stop_remaining: 7,
      configuration_valid: true, status: 'clear', global_mode: 'enforce', effective_mode: 'enforce',
      warning_permitted: true, stop_enforced: true, last_incident_at: AS_OF - 3600,
      last_warning_at: AS_OF - 172_800, next_warning_allowed_at: AS_OF + 432_000,
      last_stop_at: nil, next_stop_allowed_at: nil, accounting_since: nil,
      outstanding_stop_state: 'none', outstanding_stop_action_id: nil, outstanding_stop_chain_id: nil,
      latest_action_id: 12, latest_action_chain_id: nil, latest_notice_report_id: nil,
      latest_action_kind: 'warning', latest_action_state: 'completed', latest_mail_state: 'sent',
      latest_stop_completed_at: nil
    }.merge(changes)
    row[:id] = "#{row[:vps_id]}:#{row[:policy_key]}"
    row.merge(
      vps_url: "#{BASE_URL}?page=adminvps&action=info&veid=#{row[:vps_id]}",
      report_url: "#{BASE_URL}?page=incidents&action=list&vps=#{row[:vps_id]}",
      policy_url: "#{BASE_URL}?page=adminvps&action=incidents&veid=#{row[:vps_id]}",
      transaction_url: row[:latest_action_chain_id] && "#{BASE_URL}?page=transaction_chains&action=show&id=#{row[:latest_action_chain_id]}"
    )
  end

  def history(**changes)
    row = {
      id: 200, incident_report_id: 300, vps_id: 123, user_id: 42,
      hostname: 'sample.example.test', user_login: 'sample-owner', policy_key: 'oomd', label: 'Memory pressure',
      evaluated_at: AS_OF - 7200, detected_at: AS_OF - 7260, matched: true, state: 'recorded',
      warning_period_days: 7, stop_period_days: 30, count_7d: 3, count_30d: 10,
      warning_limit: 3, stop_limit: 10, effective_mode: 'enforce', stop_enforced: true,
      threshold_status: 'stop_threshold', decision: 'stop', action_id: 22, action_kind: 'stop',
      action_state: 'completed', action_created_at: AS_OF - 7199, action_updated_at: AS_OF - 3600,
      transaction_chain_id: 501, physical_stop_action_id: 22, stop_completed_at: AS_OF - 3600,
      notice_report_id: 301, mail_state: 'failed', mail_queued_at: nil, mail_finished_at: nil
    }.merge(changes)
    row.merge(
      vps_url: row[:vps_id] && "#{BASE_URL}?page=adminvps&action=info&veid=#{row[:vps_id]}",
      report_url: "#{BASE_URL}?page=incidents&action=show&id=#{row[:incident_report_id]}",
      policy_url: row[:vps_id] && "#{BASE_URL}?page=adminvps&action=incidents&veid=#{row[:vps_id]}",
      transaction_url: row[:transaction_chain_id] && "#{BASE_URL}?page=transaction_chains&action=show&id=#{row[:transaction_chain_id]}"
    )
  end

  def collection(rows, total_count: rows.length, url: "#{BASE_URL}?page=incidents&action=history")
    { total_count: total_count, rows: rows, omitted_count: total_count - rows.length, url: url }
  end

  def empty
    {
      as_of: AS_OF, period_start: AS_OF - 86_400, period_end: AS_OF,
      overview: collection([], url: "#{BASE_URL}?page=incidents&action=overview"),
      activity: collection([]), outstanding: collection([])
    }
  end

  def full
    invalid = exposure(
      policy_key: 'io_pressure', label: 'I/O pressure', count_7d: 4, count_30d: 7,
      warning_limit: nil, stop_limit: nil, warning_remaining: nil, stop_remaining: nil,
      configuration_valid: false, status: nil, effective_mode: nil,
      warning_permitted: nil, stop_enforced: nil, owner_active: false, transfer_pending: true,
      outstanding_stop_state: 'uncertain', outstanding_stop_action_id: 24, outstanding_stop_chain_id: 502,
      latest_action_id: 24, latest_action_chain_id: 502, latest_action_kind: 'stop',
      latest_action_state: 'uncertain', latest_mail_state: 'uncertain'
    )
    completed = history(
      evaluated_at: AS_OF - 172_800, detected_at: AS_OF - 172_860,
      action_created_at: AS_OF - 172_799, activity_at: AS_OF - 3600, activity_basis: 'stop_completed'
    )
    shared = history(
      id: 201, policy_key: 'io_pressure', label: 'I/O pressure', evaluated_at: AS_OF - 172_800,
      detected_at: AS_OF - 172_860, action_id: 23, action_created_at: AS_OF - 172_799,
      mail_state: 'queued', mail_queued_at: AS_OF - 3500, activity_at: AS_OF - 3500,
      activity_basis: 'mail_queued'
    )
    sent = history(
      id: 202, decision: 'warning', action_id: 25, action_kind: 'warning', transaction_chain_id: nil,
      physical_stop_action_id: nil, stop_completed_at: nil, notice_report_id: nil,
      mail_state: 'sent', mail_queued_at: AS_OF - 5500, mail_finished_at: AS_OF - 5400,
      activity_at: AS_OF - 5400, activity_basis: 'mail_finished', threshold_status: 'warning'
    )
    suppressed = history(
      id: 203, decision: 'warning', action_id: 26, action_kind: 'warning', transaction_chain_id: nil,
      physical_stop_action_id: nil, stop_completed_at: nil, notice_report_id: nil,
      evaluated_at: AS_OF - 10_800, detected_at: AS_OF - 10_860, action_created_at: AS_OF - 10_799,
      action_updated_at: AS_OF - 10_798, mail_state: 'suppressed', activity_at: AS_OF - 10_800,
      activity_basis: 'evaluation', threshold_status: 'warning'
    )
    uncertain = history(
      id: 204, action_id: 24, transaction_chain_id: 502, physical_stop_action_id: 24,
      evaluated_at: AS_OF - 259_200, detected_at: AS_OF - 259_260, action_created_at: AS_OF - 259_199,
      action_updated_at: AS_OF - 1800, action_state: 'uncertain', stop_completed_at: nil,
      notice_report_id: nil, mail_state: 'uncertain', activity_at: AS_OF - 1800, activity_basis: 'action_updated'
    )
    unknown = history(
      id: 205, vps_id: nil, user_id: nil, hostname: nil, user_login: nil, matched: nil,
      count_7d: nil, count_30d: nil, warning_limit: nil, stop_limit: nil, effective_mode: nil,
      stop_enforced: nil, threshold_status: nil, decision: 'warning', action_id: 27, action_kind: 'warning',
      transaction_chain_id: nil, physical_stop_action_id: nil, stop_completed_at: nil,
      notice_report_id: nil, mail_state: nil, evaluated_at: AS_OF - 14_400, detected_at: nil,
      action_created_at: AS_OF - 14_399, action_updated_at: AS_OF - 14_398,
      activity_at: AS_OF - 14_400, activity_basis: 'evaluation'
    )
    empty.merge(
      overview: collection([invalid, exposure], url: "#{BASE_URL}?page=incidents&action=overview"),
      activity: collection([uncertain, shared, completed, sent, suppressed, unknown]),
      outstanding: collection([completed, uncertain].map { |row| row.reject { |key, _| %i[activity_at activity_basis].include?(key) } })
    )
  end

  def capped
    payload = full
    %i[overview activity outstanding].each do |name|
      original = payload[name][:rows].first
      rows = 25.times.map do |n|
        changes = original.merge(policy_key: format('policy_%02d', n), label: "Policy #{n}")
        name == :overview ? exposure(**changes) : history(**changes.merge(id: 1000 + n, action_id: 2000 + n))
      end
      payload[name] = collection(rows, total_count: 28, url: payload[name][:url])
    end
    payload
  end

  def null_links
    payload = full
    %i[overview activity outstanding].each do |name|
      payload[name][:url] = nil
      payload[name][:rows].each { |row| %i[vps_url report_url policy_url transaction_url].each { |key| row[key] = nil } }
    end
    payload
  end

  def hostile
    payload = full
    %i[overview activity outstanding].each do |name|
      payload[name][:url] = 'https://example.test/?q="<collection>"&next=1'
      payload[name][:rows].each do |row|
        %i[hostname user_login node_name label policy_key].each { |key| row[key] = '<script>hostile & "value"</script>' if row.key?(key) }
        %i[vps_url report_url policy_url transaction_url].each { |key| row[key] = 'https://example.test/?q="<row>"&next=1' }
      end
    end
    payload
  end

  def variants
    { missing: nil, empty: empty, full: full, capped: capped, null_links: null_links, hostile: hostile }
  end
end
