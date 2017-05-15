module Kontena::Cli::Nodes
  class AvailabilityCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NODE_ID", "Node id"
    parameter "AVAILABILITY", "Availability"

    def execute
      require_api_url
      require_current_grid
      token = require_token

      spinner "Updating #{node_id.colorize(:cyan)} node availability to #{self.availability}" do
        client.post("nodes/#{current_grid}/#{node_id}/availability", {availability: self.availability})
      end
    end
  end
end
