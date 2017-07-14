module Kontena::Cli::Nodes
  class UpdateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    requires_current_master
    requires_current_master_token
    requires_current_grid

    parameter "NODE", "Node name"

    option ["-l", "--label"], "LABEL", "Node label", multivalued: true
    option "--clear-labels", :flag, "Clear node labels"

    option ["--token"], "TOKEN", "Node token"
    option "--generate-token", :flag, "Generate new node token"
    option "--[no-]reset-connection", :flag, "Reset agent websocket connection", default: true
    option "--force", :flag, "Force token update"

    def update_token
      confirm("Updating the node token will require you to reconfigure the kontena-agent before it will be able to reconnect. Are you sure?")

      data = {}

      data[:token] = self.token if self.token
      data[:reset_connection] = self.reset_connection?

      spinner "Updating node #{self.node.colorize(:cyan)} token" do
        client.put("nodes/#{current_grid}/#{self.node}/token", data)
      end
    end

    def execute
      self.update_token if self.token or self.generate_token?

      data = {}

      data[:labels] = self.label_list unless self.label_list.empty?
      data[:labels] = [] if self.clear_labels?

      spinner "Updating #{self.node.colorize(:cyan)} node " do
        client.put("nodes/#{current_grid}/#{self.node}", data)
      end
    end
  end
end
