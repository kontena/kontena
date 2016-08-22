require_relative 'common'

module Kontena::Cli::Grids
  class EnvCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    parameter "[NAME]", "Grid name"
    option ["-e", "--export"], :flag, "Add export", default: false

    def execute
      require_api_url

      name_or_current = name.nil? ? current_grid : name

      if name_or_current.nil?
        abort "No grid selected. Use: kontena grid env <name>, or select a grid with: kontena grid use <name>"
      else
        grid = find_grid_by_name(name_or_current)
        abort("Grid not found".colorize(:red)) unless grid

        prefix = export? ? 'export ' : ''

        server = settings['servers'].find{|s| s['name'] == settings['current_server']}
        if server
          puts "#{prefix}KONTENA_URI=#{server['url'].sub('http', 'ws')}"
          puts "#{prefix}KONTENA_TOKEN=#{server['token']}"
        end
      end
    end
  end
end
