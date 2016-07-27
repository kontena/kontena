require_relative '../services/log_helper'

module Kontena::Cli::Stacks
  class LogsCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Services::LogHelper

    parameter "NAME", "Stack name"
    option ["-t", "--tail"], :flag, "Tail (follow) logs", default: false
    option ["-l", "--lines"], "LINES", "How many lines to show", default: '100'
    option "--since", "SINCE", "Show logs since given timestamp"

    def execute
      require_api_url
      token = require_token

      query_params = {}
      query_params[:limit] = lines if lines
      query_params[:since] = since if since

      if tail?
        @buffer = ''
        query_params[:follow] = 1
        stream_logs(token, query_params)
      else
        list_logs(token, query_params)
      end

    end

    def list_logs(token, query_params)
      result = client(token).get("stacks/#{current_grid}/#{name}/container_logs", query_params)
      result['logs'].each do |log|
        render_log_line(log)
      end
    end

    def stream_logs(token, query_params)
      begin
        query_params[:follow] = true
        if @last_seen
          query_params[:from] = @last_seen
        end
        result = client(token).get_stream(
          "stacks/#{current_grid}/#{name}/container_logs", log_stream_parser, query_params
        )
      rescue => exc
        if exc.cause.is_a?(EOFError) # Excon wraps the EOFerror into SockerError
          retry
        end
      end
    end
  end
end
