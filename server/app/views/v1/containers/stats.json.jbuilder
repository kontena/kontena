json.from @from
json.to @to
json.sort @sort
json.limit @limit
json.containers @containers do |container|
  json.id container["id"]
  json.name container["name"]
  json.cpu do
    json.used container["cpu"]["percent_used"].round(2)
    json.cores container["cpu"]["num_cores"].to_i
  end
  json.memory do
    json.used container["memory"]["used"].to_i
    json.total container["memory"]["total"].to_i
  end
  json.network do
    json.name container["network"]["name"]
    json.in container["network"]["rx_bytes"].to_i
    json.out container["network"]["tx_bytes"].to_i
  end
end
