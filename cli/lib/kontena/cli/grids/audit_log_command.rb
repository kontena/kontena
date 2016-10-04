require_relative 'common'

module Kontena::Cli::Grids
  class AuditLogCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    option ["-l", "--lines"], "LINES", "Number of lines"

    def execute
      require_api_url
      require_current_grid
      token = require_token
      audit_logs = client(token).get("grids/#{current_grid}/audit_log", {limit: lines})
      puts '%-30.30s %-10s %-15s %-25s %-15s %-25s %-15s %-15s' % ['Time', 'Grid', 'Resource Type', 'Resource Name', 'Event Name', 'User', 'Source IP', 'User-Agent']
      audit_logs['logs'].each do |log|
        puts '%-30.30s %-10s %-15s %-25s %-15s %-25s %-15s %-15s' % [ log['time'], log['grid'], log['resource_type'], log['resource_name'], log['event_name'], log['user_identity']['email'], log['source_ip'], log['user_agent']]
      end
    end
  end
end
