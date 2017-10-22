module Kontena::Cli::Grids::TrustedSubnets
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::GridOptions

    parameter "SUBNET", "Trusted subnet"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    requires_current_master

    def execute
      grid = client.get("grids/#{current_grid}")
      confirm_command(subnet) unless forced?
      trusted_subnets = grid['trusted_subnets'] || []
      unless trusted_subnets.delete(self.subnet)
        exit_with_error("Grid #{current_grid.colorize(:cyan)} does not have trusted subnet #{subnet.colorize(:cyan)}")
      end
      data = {trusted_subnets: trusted_subnets}
      spinner "Removing trusted subnet #{subnet.colorize(:cyan)} from #{current_grid.colorize(:cyan)} grid " do
        client.put("grids/#{current_grid}", data)
      end
    end
  end
end
