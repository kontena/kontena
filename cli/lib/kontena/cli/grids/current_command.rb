require_relative 'common'

module Kontena::Cli::Grids
  class CurrentCommand < Kontena::Command
    include Common

    option ["--name"], :flag, "Show name only", default: false

    def execute
      require_api_url
      if current_grid.nil?
        exit_with_error 'No grid selected. To select grid, please run: kontena grid use <grid name>'
      else

        grid = client(require_token).get("grids/#{current_grid}")
        if name?
          puts "#{grid['name']}"
        else
          print_grid(grid)
        end
      end
    end
  end
end
