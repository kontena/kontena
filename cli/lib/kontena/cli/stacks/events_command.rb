require_relative '../helpers/log_helper'

module Kontena::Cli::Stacks
  class EventsCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::LogHelper

    parameter "NAME", "Service name"

    def execute
      require_api_url

      query_params = {}
      titles = ['TIME', 'TYPE', 'MESSAGE']
      puts "%-25s %-25s %s" % titles
      show_logs("stacks/#{current_grid}/#{name}/event_logs", query_params) do |log|
        show_log(log)
      end
    end

    def show_log(log)
      msg = log['message']
      node = log['relationships'].find { |r| r['type'] == 'node' }
      if node
        msg = "#{msg} (#{node['id'].split('/')[-1]})"
      end
      puts '%-25s %-25s %s' % [
        log['created_at'], log['type'], msg
      ]
    end
  end
end
