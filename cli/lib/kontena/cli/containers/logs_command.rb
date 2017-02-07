require_relative '../grid_options'
require_relative '../helpers/log_helper'
require_relative 'container_id_param'

module Kontena::Cli::Containers
  class LogsCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::LogHelper

    include Kontena::Cli::Containers::ContainerIdParam

    requires_current_master
    requires_current_master_token

    def execute
      show_logs("containers/#{current_grid}/#{container_id}/logs") do |log|
        show_log(log)
      end
    rescue Kontena::Errors::StandardError => ex
      if ex.message =~ /Not [Ff]ound/
        if new_target = resolve(container_id)
          self.container_id = container_id
          return exec(payload, new_target)
        end
      end
      raise ex, ex.message
    end
  end
end
