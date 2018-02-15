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
    option "--availability", "active|drain", "Node scheduling availability"

    def execute
      data = {}

      data[:labels] = self.label_list unless self.label_list.empty?
      data[:labels] = [] if self.clear_labels?

      data[:availability] = availability if availability
      spinner "Updating #{pastel.cyan(self.node)} node " do
        client.put("nodes/#{current_grid}/#{self.node}", data)
      end
    end
  end
end
