require_relative '../helpers/log_helper'

module Kontena::Cli::Grids
  class LogsCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Helpers::LogHelper

    option ["-t", "--tail"], :flag, "Tail (follow) logs", default: false
    option "--lines", "LINES", "Number of lines to show from the end of the logs"
    option "--since", "SINCE", "Show logs since given timestamp"
    option "--node", "NODE", "Filter by node name", multivalued: true
    option "--service", "SERVICE", "Filter by service name", multivalued: true
    option ["-c", "--container"], "CONTAINER", "Filter by container", multivalued: true

    def execute
      require_api_url
      token = require_token

      query_params = {}
      query_params[:nodes] = node_list.join(",") unless node_list.empty?
      query_params[:services] = service_list.join(",") unless service_list.empty?
      query_params[:containers] = container_list.join(",") unless container_list.empty?
      query_params[:limit] = lines if lines
      query_params[:since] = since if since

      if tail?
        tail_logs(token, query_params)
      else
        list_logs(token, query_params)
      end
    end

    def list_logs(token, query_params)
      result = client(token).get("grids/#{current_grid}/container_logs", query_params)
      result['logs'].each do |log|
        color = color_for_container(log['name'])
        prefix = ""
        prefix << "#{log['created_at']} "
        prefix << "#{log['name']}:"
        prefix = prefix.colorize(color)
        puts "#{prefix} #{log['data']}"
      end
    end

    # @param [String] token
    # @param [Hash] query_params
    def tail_logs(token, query_params)
      stream_logs("grids/#{current_grid}/container_logs", query_params) do |log|
        color = color_for_container(log['name'])
        puts "#{log['name'].colorize(color)} | #{log['data']}"
      end
    end
  end
end
