require_relative '../helpers/log_helper'

module Kontena::Cli::Grids
  class EventsCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Helpers::LogHelper

    SKIP_TYPES = ['grid']

    option "--node", "NODE", "Filter by node name", multivalued: true
    option "--service", "SERVICE", "Filter by service name", multivalued: true

    def execute
      require_api_url

      query_params = {}
      query_params[:nodes] = node_list.join(",") unless node_list.empty?
      query_params[:services] = service_list.join(",") unless service_list.empty?

      titles = ['TIME', 'TYPE', 'RELATIONSHIPS', 'MESSAGE']
      puts "%-25s %-25s %-40s %s" % titles
      show_logs("grids/#{current_grid}/event_logs", query_params) do |log|
        show_log(log)
      end
    end

    def show_log(log)
      msg = log['message']
      rels = log['relationships'].
        delete_if { |r| SKIP_TYPES.include?(r['type']) }.
        map { |r|
          id = r['id'].split('/')[1..-1].delete_if{ |s| s == 'null'}.join('/')
          unless id.empty?
            "#{r['type']}=#{id}"
          end
        }.compact

      time = log['created_at']
      if log['severity'] == 2
        time = pastel.yellow(time)
      elsif log['severity'] >= 3
        time = pastel.red(time)
      end

      puts '%-25s %-25s %-40s %s' % [
        time, log['type'], rels.join(','), msg
      ]
    end
  end
end
