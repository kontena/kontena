module Kontena::Cli::Grids::TrustedSubnets
  class AddCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "NAME", "Grid name"
    parameter "SUBNET", "Trusted subnet"

    def execute
      require_api_url
      token = require_token
      grid = client(token).get("grids/#{current_grid}")
      data = {trusted_subnets: grid['trusted_subnets'] + [self.subnet]}
      client(token).put("grids/#{current_grid}", data)
    end
  end
end
