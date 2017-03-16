json.from @from
json.to @to
json.stats @node_stats do |stat|
  json.timestamp Time.new(stat["timestamp"]["year"], stat["timestamp"]["month"], stat["timestamp"]["day"], stat["timestamp"]["hour"], stat["timestamp"]["minute"], 0, "+00:00")
  json.cpu do
    json.used stat["cpu"]["percent_used"].round(2)
    json.cores stat["cpu"]["num_cores"].to_i
  end
  json.memory do
    json.used stat["memory"]["used"].to_i
    json.total stat["memory"]["total"].to_i
  end
  json.filesystem do
    json.used stat["filesystem"]["used"].to_i
    json.total stat["filesystem"]["total"].to_i
  end
  json.network stat["network"] do |network|
    json.name network["name"]
    json.in network["rx_bytes"].to_i
    json.out network["tx_bytes"].to_i
  end
end
