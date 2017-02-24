json.created_at volume.created_at
json.updated_at volume.updated_at
json.id volume.to_path
json.name volume.name
json.scope volume.scope
json.driver volume.driver
json.driver_opts volume.driver_opts
if volume.stack
  json.stack do
    json.id volume.stack.to_path
    json.name volume.stack.name
  end
end
