require_relative 'common'

module Kontena::Cli::Grids
  class RemoveCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common

    parameter "NAME", "Grid name"
    option "--confirm", :flag, "Confirm remove", default: false, attribute_name: :confirmed

    def execute
      require_api_url
      token = require_token
      confirm_command(name) unless confirmed?
      grid = find_grid_by_name(name)

      if !grid.nil?
        response = client(token).delete("grids/#{grid['id']}")
        if response
          clear_current_grid if grid['id'] == current_grid
          puts "removed #{grid['name'].cyan}"
        end
      else
        abort "Could not resolve grid by name [#{name}]. For a list of existing grids please run: kontena grid list".colorize(:red)
      end
    end
  end
end
