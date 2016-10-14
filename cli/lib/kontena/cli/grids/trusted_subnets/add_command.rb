module Kontena::Cli::Grids::TrustedSubnets
  class AddCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "NAME", "Grid name"
    parameter "SUBNET", "Trusted subnet"

    requires_current_master_token

    def execute
      grid = client.get("grids/#{name}")
      data = {trusted_subnets: grid['trusted_subnets'] + [self.subnet]}
      spinner "Adding #{subnet.colorize(:cyan)} as a trusted subnet in #{name.colorize(:cyan)} grid " do
        client.put("grids/#{name}", data)
      end
    end
  end
end
