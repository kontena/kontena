require_relative '../helpers/log_helper'

module Kontena::Cli::Stacks
  class LogsCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::LogHelper

    banner "Shows logs from services in a stack"

    parameter "NAME", "Stack name"

    requires_current_master
    requires_current_master_token

    def execute
      show_logs("stacks/#{current_grid}/#{name}/container_logs") do |log|
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
