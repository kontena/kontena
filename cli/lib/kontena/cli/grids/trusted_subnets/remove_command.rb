module Kontena::Cli::Grids::TrustedSubnets
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "SUBNET", "Trusted subnet"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    requires_current_master

    def execute
      grid = client.get("grids/#{current_grid}")
      confirm_command(subnet) unless forced?
      trusted_subnets = grid['trusted_subnets'] || []
      unless trusted_subnets.delete(self.subnet)
        exit_with_error("Grid #{pastel.cyan(current_grid)} does not have trusted subnet #{pastel.cyan(subnet)}")
      end
      data = {trusted_subnets: trusted_subnets}
      spinner "Removing trusted subnet #{pastel.cyan(subnet)} from #{pastel.cyan(current_grid)} grid " do
        client.put("grids/#{current_grid}", data)
      end
    end
  end
end
