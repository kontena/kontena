module Kontena::Cli::Nodes::Labels
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "NODE", "Node name"
    parameter "LABEL ...", "Labels"

    option '--force', :flag, "Do not abort if items in label list are not found"

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def execute
      node_data = client.get("nodes/#{current_grid}/#{self.node}")

      node_data['labels'] ||= []

      found_labels = label_list.uniq & node_data['labels']

      if !force? && found_labels.size != label_list.uniq.size
        missing = label_list - found_labels
        exit_with_error "Label#{'s' if missing.size > 1} #{pastel.cyan(missing.join(', '))} not found on node #{pastel.cyan(node)}"
      end

      return nil if found_labels.empty?

      data = { labels: node_data['labels'] - found_labels }
      client.put("nodes/#{node_data['id']}", data)
    end
  end
end
