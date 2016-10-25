module Kontena::Cli::Grids::TrustedSubnets
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "NAME", "Grid name"
    parameter "SUBNET", "Trusted subnet"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      token = require_token
      grid = client(token).get("grids/#{name}")
      confirm_command(subnet) unless forced?
      trusted_subnets = grid['trusted_subnets'] || []
      unless trusted_subnets.delete(self.subnet)
        exit_with_error("Grid #{name.colorize(:cyan)} does not have trusted subnet #{subnet.colorize(:cyan)}")
      end
      data = {trusted_subnets: trusted_subnets}
      spinner "Removing trusted subnet #{subnet.colorize(:cyan)} from #{name.colorize(:cyan)} grid " do
        client(token).put("grids/#{name}", data)
      end
    end
  end
end
