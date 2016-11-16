require_relative 'common'

module Kontena::Cli::Grids
  class AuditLogCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    SERVICE_MAP = {
      'Grid' => 'grid',
      'GridService' => 'service',
      'GridSecret' => 'vault',
      'HostNode' => 'node',
      'Stack' => 'stack',
      'User' => 'user'
    }

    parameter "[NAME]", "Grid name", required: false
    option ["-l", "--lines"], "LINES", "Number of lines", default: 50

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def execute
      grid = name || current_grid
      audit_logs = client.get("grids/#{grid}/audit_log", {limit: lines})
      columns = ['Time', 'Type', 'Resource', 'Event', 'User', 'Source IP', 'User-Agent']
      puts '%-25s %-10s %-30s %-15s %-25s %-15s %-15s' % columns
      audit_logs['logs'].each do |log|
        ts = pastel.decorate(log['time'], color_for("#{log['resource_name']}/#{log['response_type']}"))
        columns = [
          ts, friendly_resource_type(log['resource_type']), log['resource_name'], log['event_name'],
          log['user_identity']['email'], log['source_ip'], log['user_agent']
        ]
        puts '%-34s %-10s %-30s %-15s %-25s %-15s %-15s' % columns
      end
    end

    def friendly_resource_type(type)
      SERVICE_MAP[type] || type
    end

    # @param [String] subject
    # @return [Symbol]
    def color_for(subject)
      color_maps[subject] = colors.shift unless color_maps[subject]
      color_maps[subject].to_sym
    end

    # @return [Hash]
    def color_maps
      @color_maps ||= {}
    end

    # @return [Array<Symbol>]
    def colors
      if(@colors.nil? || @colors.size == 0)
        @colors = %i(
          green yellow blue magenta cyan red bright_green
          bright_yellow bright_blue bright_magenta bright_cyan bright_red 
        )
      end
      @colors
    end
  end
end
