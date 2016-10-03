module Kontena::Cli::Grids::TrustedSubnets
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "NAME", "Grid name"

    def execute
      require_api_url
      token = require_token
      grid = client(token).get("grids/#{current_grid}")
      trusted_subnets = grid['trusted_subnets'] || []
      trusted_subnets.each do |subnet|
        puts subnet
      end
    end
  end
end
