module Kontena::Cli::Nodes
  class UpdateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NODE", "Node name"
    option ["-l", "--label"], "LABEL", "Node label", multivalued: true

    def execute
      require_api_url
      require_current_grid
      token = require_token

      data = {}
      data[:labels] = label_list if label_list
      spinner "Updating #{self.node.colorize(:cyan)} node " do
        client.put("nodes/#{current_grid}/#{self.node}", data)
      end
    end
  end
end
