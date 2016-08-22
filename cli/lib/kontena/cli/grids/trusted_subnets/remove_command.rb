module Kontena::Cli::Grids::TrustedSubnets
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "NAME", "Grid name"
    parameter "SUBNET", "Trusted subnet"

    def execute
      require_api_url
      token = require_token
      grid = client(token).get("grids/#{name}")
      trusted_subnets = grid['trusted_subnets'] || []
      unless trusted_subnets.delete(self.subnet)
        abort("Grid does not have trusted subnet #{self.subnet}")
      end
      data = {trusted_subnets: trusted_subnets}
      client(token).put("grids/#{name}", data)
    end
  end
end
