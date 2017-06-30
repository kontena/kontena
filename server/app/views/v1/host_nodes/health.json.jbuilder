json.id @node.to_path
json.name @node.name
json.node_number @node.node_number
json.initial_member @node.initial_member?

json.connected @node.connected
json.etcd_health do
  json.health @etcd_health[:health]
  json.error @etcd_health[:error]
end
