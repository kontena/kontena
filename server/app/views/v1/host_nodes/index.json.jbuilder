json.nodes @nodes do |node|
  json.partial! 'app/views/v1/host_nodes/host_node', node: node
end
