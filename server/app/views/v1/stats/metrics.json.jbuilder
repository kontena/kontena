json.from @from
json.to @to
json.stats @metrics do |stat|
  json.timestamp Time.new(stat["timestamp"]["year"], stat["timestamp"]["month"], stat["timestamp"]["day"], stat["timestamp"]["hour"], stat["timestamp"]["minute"], 0, "+00:00")
  json.cpu do
    json.used stat["cpu"]["percent_used"].round(2)
    json.cores stat["cpu"]["num_cores"].to_i
  end
  json.memory do
    json.used stat["memory"]["used"].to_i
    json.total stat["memory"]["total"].to_i
    json.free stat["memory"]["free"].to_i
    json.active stat["memory"]["active"].to_i
    json.inactive stat["memory"]["inactive"].to_i
    json.cached stat["memory"]["cached"].to_i
    json.buffers stat["memory"]["buffers"].to_i
  end
  if !stat["filesystem"].nil?
    json.filesystem do
      json.used stat["filesystem"]["used"].to_i
      json.total stat["filesystem"]["total"].to_i
    end
  end
  json.network do
    json.internal do
      json.interfaces stat["network"]["internal"]["interfaces"]
      json.rx_bytes stat["network"]["internal"]["rx_bytes"]
      json.rx_bytes_per_second stat["network"]["internal"]["rx_bytes_per_second"]
      json.tx_bytes stat["network"]["internal"]["tx_bytes"]
      json.tx_bytes_per_second stat["network"]["internal"]["tx_bytes_per_second"]
    end
    json.external do
      json.interfaces stat["network"]["external"]["interfaces"]
      json.rx_bytes stat["network"]["external"]["rx_bytes"]
      json.rx_bytes_per_second stat["network"]["external"]["rx_bytes_per_second"]
      json.tx_bytes stat["network"]["external"]["tx_bytes"]
      json.tx_bytes_per_second stat["network"]["external"]["tx_bytes_per_second"]
    end
  end
end
