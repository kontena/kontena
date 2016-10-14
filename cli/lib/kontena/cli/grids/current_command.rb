require_relative 'common'

module Kontena::Cli::Grids
  class CurrentCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    option ["--name"], :flag, "Show name only", default: false

    requires_current_master_token

    def execute
      if current_grid.nil?
        exit_with_error 'No grid selected. To select grid, please run: kontena grid use <grid name>'
      else
        begin
          grid = client.get("grids/#{current_grid}")
        rescue Kontena::Errors::StandardError
          if $!.message =~ /Not found/
            abort pastel.red('Grid not found')
          end
        end
        if name?
          puts "#{grid['name']}"
        else
          print_grid(grid)
        end
      end
    end
  end
end
