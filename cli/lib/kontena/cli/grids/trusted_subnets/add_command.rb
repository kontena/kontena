module Kontena::Cli::Grids::TrustedSubnets
  class AddCommand < Kontena::Command
    include Kontena::Cli::GridOptions

    parameter "SUBNET", "Trusted subnet"

    requires_current_master

    def execute
      grid = client.get("grids/#{current_grid}")
      data = {trusted_subnets: grid['trusted_subnets'] + [self.subnet]}
      spinner "Adding #{subnet.colorize(:cyan)} as a trusted subnet in #{current_grid.colorize(:cyan)} grid " do
        client.put("grids/#{current_grid}", data)
      end
    end
  end
end
