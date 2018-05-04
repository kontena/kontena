module Kontena::Cli::Nodes
  class UpdateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    requires_current_master
    requires_current_master_token
    requires_current_grid

    parameter "NODE ...", "Node name", attribute_name: :nodes

    option ["-l", "--label"], "LABEL", "Node label", multivalued: true
    option "--clear-labels", :flag, "Clear node labels"
    option "--availability", "active|drain", "Node scheduling availability"

    def execute
      data = {}

      data[:labels] = self.label_list unless self.label_list.empty?
      data[:labels] = [] if self.clear_labels?

      data[:availability] = availability if availability

      nodes.each do |node_name|
        spinner "Updating node #{pastel.cyan(node_name)} " do
          client.put("nodes/#{current_grid}/#{node_name}", data)
        end
      end
    end
  end
end
