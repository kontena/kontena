json.id @node.node_id
json.name @node.name
json.node_number @node.node_number
json.initial_member @node.initial_member?

json.connected @node.connected
json.websocket_connection do
  json.connected_at @node.connected_at
  json.disconnected_at @node.disconnected_at
  json.error @node.connection_error
end
json.etcd_health do
  json.health @etcd_health[:health]
  json.error @etcd_health[:error]
end
