require_relative 'services_helper'
require_relative '../helpers/log_helper'

module Kontena::Cli::Services
  class EventsCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::LogHelper
    include ServicesHelper

    parameter "NAME", "Service name"

    def execute
      require_api_url

      query_params = {}

      titles = ['TIME', 'TYPE', 'MESSAGE']
      puts "%-25s %-20s %s" % titles
      show_logs("services/#{parse_service_id(name)}/event_logs", query_params) do |log|
        show_log(log)
      end
    end

    def show_log(log)
      msg = log['message']
      node = log['relationships'].find { |r| r['type'] == 'node' }
      if node
        msg = "#{msg} (#{node['id'].split('/')[-1]})"
      end
      puts '%-25s %-20s %s' % [
        log['created_at'], log['type'].sub('service:'.freeze, ''.freeze), msg
      ]
    end
  end
end
