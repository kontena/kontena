require_relative 'services_helper'
require_relative '../helpers/log_helper'

module Kontena::Cli::Services
  class LogsCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::LogHelper
    include ServicesHelper

    parameter "NAME", "Service name"
    option ["-t", "--tail"], :flag, "Tail (follow) logs", default: false
    option ["-l", "--lines"], "LINES", "How many lines to show", default: '100'
    option "--since", "SINCE", "Show logs since given timestamp"
    option ["-i", "--instance"], "INSTANCE", "Show only given instance specific logs"

    def execute
      require_api_url
      token = require_token


      query_params = {}
      query_params[:limit] = lines if lines
      query_params[:since] = since if since
      query_params[:container] = "#{name}-#{instance}" if instance

      if tail?
        @buffer = ''
        query_params[:follow] = 1
        stream_logs(token, query_params)
      else
        list_logs(token, query_params)
      end

    end

    def render_log_line(log)
      color = color_for_container(log['name'])
      instance_number = log['name'].match(/^.+-(\d+)$/)[1]
      name = instance_number.nil? ? log['name'] : instance_number
      prefix = "#{log['created_at']} [#{name}]:".colorize(color)
      puts "#{prefix} #{log['data']}"
    end

    def list_logs(token, query_params)
      result = client(token).get("services/#{current_grid}/#{name}/container_logs", query_params)
      result['logs'].each do |log|
        render_log_line(log)
      end
    end

    # @param [String] token
    # @param [Hash] query_params
    def stream_logs(token, query_params)
      last_seen = nil
      streamer = lambda do |chunk, remaining_bytes, total_bytes|
        log = buffered_log_json(chunk)
        if log
          last_seen = log['id']
          render_log_line(log)
        end
      end

      begin
        query_params[:follow] = true
        if last_seen
          query_params[:from] = last_seen
        end
        result = client(token).get_stream(
          "services/#{current_grid}/#{name}/container_logs", streamer, query_params
        )
      rescue => exc
        retry if exc.cause.is_a?(EOFError) # Excon wraps the EOFerror into SocketError
        raise
      end
    end
  end
end
