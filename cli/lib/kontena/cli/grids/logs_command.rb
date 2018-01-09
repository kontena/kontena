require_relative '../helpers/log_helper'

module Kontena::Cli::Grids
  class LogsCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Helpers::LogHelper
    option "--node", "NODE", "Filter by node name", multivalued: true
    option "--service", "SERVICE", "Filter by service name", multivalued: true
    option ["-c", "--container"], "CONTAINER", "Filter by container", multivalued: true

    def execute
      require_api_url

      query_params = {}
      query_params[:nodes] = node_list.join(",") unless node_list.empty?
      query_params[:services] = service_list.join(",") unless service_list.empty?
      query_params[:containers] = container_list.join(",") unless container_list.empty?

      show_logs("grids/#{current_grid}/container_logs", query_params) do |log|
        show_log(log)
      end
    end

    def show_log(log)
      color = color_for_container(log['name'])
      if tail?
        prefix = "#{log['name']} |"
      else
        prefix = "#{log['created_at']} #{log['name']}:"
      end

      puts "#{pastel.send(color, prefix)} #{log['data']}"
    end
  end
end
