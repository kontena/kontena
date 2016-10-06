module Kontena::Cli::Nodes::Labels
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NODE_ID", "Node id"
    parameter "LABEL", "Label"

    requires_current_master_token

    def execute
      node = client.get("grids/#{current_grid}/nodes/#{node_id}")
      unless node['labels'].include?(label)
        exit_with_error("Node #{node['name']} does not have label #{label}")
      end
      node['labels'].delete(label)
      data = {}
      data[:labels] = node['labels']
      client.put("nodes/#{node['id']}", data, {}, {'Kontena-Grid-Token' => node['grid']['token']})
    end
  end
end
