require_relative 'common'

module Kontena::Cli::Grids
  class EnvCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    parameter "[NAME]", "Grid name"
    option ["-e", "--export"], :flag, "Add export", default: false

    requires_current_master_token

    def execute
      name_or_current = name.nil? ? current_grid : name

      if name_or_current.nil?
        exit_with_error "No grid selected. Use: kontena grid env <name>, or select a grid with: kontena grid use <name>"
      else
        grid = find_grid_by_name(name_or_current)
        exit_with_error("Grid not found") unless grid

        prefix = export? ? 'export ' : ''

        server = current_master
        if server
          puts "#{prefix}KONTENA_URI=#{server.url.sub('http', 'ws')}"
          puts "#{prefix}KONTENA_TOKEN=#{server.token.access_token}"
        end
      end
    end
  end
end
