json.from @from
json.to @to
json.stats @node_stats do |stat|
  json.timestamp Time.new(stat["timestamp"]["year"], stat["timestamp"]["month"], stat["timestamp"]["day"], stat["timestamp"]["hour"], stat["timestamp"]["minute"], 0, "+00:00")
  json.cpu do
    json.used stat["cpu"]["percent_used"].round(2)
    json.cores stat["cpu"]["num_cores"]
  end
  json.memory do
    json.used stat["memory"]["used"]
    json.total stat["memory"]["total"]
  end
  json.filesystem do
    json.used stat["filesystem"]["used"]
    json.total stat["filesystem"]["total"]
  end
  json.network stat["network"] do |network|
    json.name network["name"]
    json.in network["rx_bytes"]
    json.out network["tx_bytes"]
  end
end
