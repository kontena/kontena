require_relative 'common'

module Kontena::Cli::Grids
  class EnvCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    parameter "[GRID_NAME]", "Grid name", attribute_name: :name
    option ["-e", "--export"], :flag, "Add export", default: false

    def execute
      require_api_url

      name_or_current = name.nil? ? current_grid : name

      if name_or_current.nil?
        exit_with_error "No grid selected. Use: kontena grid env <name>, or select a grid with: kontena grid use <name>"
      else
        grid = find_grid_by_name(name_or_current)
        exit_with_error("Grid not found") unless grid

        grid_uri = self.current_master['url'].sub('http', 'ws')


        prefix = export? ? 'export ' : ''

        puts "#{prefix}KONTENA_URI=#{grid_uri}"
        puts "#{prefix}KONTENA_TOKEN=#{grid['token']}"
      end
    end
  end
end
