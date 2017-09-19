json.id @node.to_path
json.name @node.name
json.node_number @node.node_number
json.initial_member @node.initial_member?

json.status @node.status
json.connected_at @node.connected_at
json.disconnected_at @node.disconnected_at
json.connected @node.connected

json.etcd_health do
  json.health @node_health[:etcd_health][:health]
  json.error @node_health[:etcd_health][:error]
end
