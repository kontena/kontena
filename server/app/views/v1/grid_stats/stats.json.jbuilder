json.from @from
json.to @to
json.stats @grid_stats do |stat|
  json.timestamp Time.new(stat["timestamp"]["year"], stat["timestamp"]["month"], stat["timestamp"]["day"], stat["timestamp"]["hour"], stat["timestamp"]["minute"], 0, "+00:00")
  json.cpu_percent stat["cpu_percent"]
  json.memory do
    json.used stat["memory_used"]
    json.total stat["memory_total"]
  end
  json.filesystem do
    json.used stat["filesystem_used"]
    json.total stat["filesystem_total"]
  end
  json.network do
    json.in stat["network_in_bytes"]
    json.out stat["network_out_bytes"]
  end
end
