module Kontena::Cli::Stacks
  class LogsCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::LogHelper

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

      show_logs("stacks/#{current_grid}/#{name}/container_logs", query_params) do |log|
        show_log(log)
      end
    end

    def show_log(log)
      color = color_for_container(log['name'])
      prefix = "#{log['created_at']} [#{log['name']}]:".colorize(color)
      puts "#{prefix} #{log['data']}"
    end
  end
end
