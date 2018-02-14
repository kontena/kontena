require_relative 'common'

module Kontena::Cli::Grids
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    parameter "NAME ...", "Grid name"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      token = require_token
      name_list.each do |name|
        confirm_command(name) unless forced?
        grid = find_grid_by_name(name)

        if !grid.nil?
          spinner "removing #{pastel.cyan(name)} grid " do
            response = client(token).delete("grids/#{grid['id']}")
            if response
              clear_current_grid if grid['id'] == current_grid
            end
          end
        else
          exit_with_error "Could not resolve grid by name [#{name}]. For a list of existing grids please run: kontena grid list"
        end
      end
    end
  end
end
