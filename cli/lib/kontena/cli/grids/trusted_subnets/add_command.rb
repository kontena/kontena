module Kontena::Cli::Grids::TrustedSubnets
  class AddCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "SUBNET", "Trusted subnet"

    requires_current_master

    def execute
      grid = client.get("grids/#{current_grid}")
      data = {trusted_subnets: grid['trusted_subnets'] + [self.subnet]}
      spinner "Adding #{pastel.cyan(subnet)} as a trusted subnet in #{pastel.cyan(current_grid)} grid " do
        client.put("grids/#{current_grid}", data)
      end
    end
  end
end
