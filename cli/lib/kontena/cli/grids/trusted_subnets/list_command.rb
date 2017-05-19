module Kontena::Cli::Grids::TrustedSubnets
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

<<<<<<< Updated upstream
    requires_current_master
=======
    parameter "GRID_NAME", "Grid name", attribute_name: :name
>>>>>>> Stashed changes

    def execute
      grid = client.get("grids/#{current_grid}")
      trusted_subnets = grid['trusted_subnets'] || []
      trusted_subnets.each do |subnet|
        puts subnet
      end
    end
  end
end
