require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Grids
  class AuditLog
    include Kontena::Cli::Common

    def show(options)
      require_api_url
      token = require_token
      audit_logs = client(token).get("grids/#{current_grid}/audit_log", {limit: options.limit})
      headings = ['time', 'grid', 'resource type', 'resource name', 'event name', 'user', 'source ip', 'user agent']
      rows = []
      audit_logs['logs'].each do |log|

        rows << [ log['time'], log['grid'], log['resource_type'], log['resource_name'], log['event_name'], log['user_identity']['email'], log['source_ip'], log['user_agent']]
      end
      table = Terminal::Table.new :headings => headings, :rows => rows
      puts table
    end
  end
end