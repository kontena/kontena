module Kontena::Cli::Grids::TrustedSubnets
  class AddCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "NAME", "Grid name"
    parameter "SUBNET", "Trusted subnet"

    def execute
      require_api_url
      token = require_token
      grid = client(token).get("grids/#{name}")
      data = {trusted_subnets: grid['trusted_subnets'] + [self.subnet]}
      client(token).put("grids/#{name}", data)
    end
  end
end
