require_relative '../helpers/log_helper'

module Kontena::Cli::Containers
  class LogsCommand < Kontena::Command
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::LogHelper

    parameter "CONTAINER_ID", "Container id"

    def execute
      require_api_url

      show_logs("containers/#{current_grid}/#{container_id}/logs") do |log|
        show_log(log)
      end
    end
  end
end
