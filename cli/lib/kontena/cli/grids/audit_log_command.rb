require_relative 'common'

module Kontena::Cli::Grids
  class AuditLogCommand < Kontena::Command
    include Common

    option ["-l", "--lines"], "LINES", "Number of lines"

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def execute
      audit_logs = client.get("grids/#{current_grid}/audit_log", {limit: lines})
      puts '%-30.30s %-10s %-15s %-25s %-15s %-25s %-15s %-15s' % ['Time', 'Grid', 'Resource Type', 'Resource Name', 'Event Name', 'User', 'Source IP', 'User-Agent']
      audit_logs['logs'].each do |log|
        puts '%-30.30s %-10s %-15s %-25s %-15s %-25s %-15s %-15s' % [ log['time'], log['grid'], log['resource_type'], log['resource_name'], log['event_name'], log['user_identity']['email'], log['source_ip'], log['user_agent']]
      end
    end
  end
end
