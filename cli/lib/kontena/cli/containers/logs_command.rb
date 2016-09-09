require_relative '../grid_options'
require_relative '../helpers/log_helper'

module Kontena::Cli::Containers
  class LogsCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::LogHelper

    parameter "CONTAINER_ID", "Container id"

    def execute
      require_api_url

      service_name = container_id.match(/(.+)-(\d+)/)[1] rescue nil

      show_logs("containers/#{current_grid}/#{service_name}/#{container_id}/logs") do |log|
        show_log(log)
      end
    end
  end
end
