json.id service_instance.id.to_s
json.created_at service_instance.created_at
json.updated_at service_instance.updated_at
json.instance_number service_instance.instance_number
json.desired_state service_instance.desired_state
json.state service_instance.state
json.deploy_rev service_instance.deploy_rev
json.rev service_instance.rev
json.error service_instance.error
json.node do
  if node = service_instance.host_node
    json.id node.to_path
    json.name node.name
    json.public_ip node.public_ip
  end
end
