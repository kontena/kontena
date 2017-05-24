module Kontena::Cli::Nodes::Labels
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "[NODE_NAME]", "Node name", attribute_name: :node_id

    option ['-a', '--all'], :flag, "List labels on all nodes in the grid"

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def execute
      if node_id.nil? && !all?
        exit_with_error "NODE_NAME or --all missing"
      elsif node_id && all?
        exit_with_error "NODE_NAME and --all can't be used together"
      end

      nodes = all? ? client.get("grids/#{current_grid}/nodes")['nodes'] : [client.get("nodes/#{current_grid}/#{node_id}")]
      puts nodes.flat_map { |n| n['labels'] }.uniq.join("\n")
    end
  end
end
