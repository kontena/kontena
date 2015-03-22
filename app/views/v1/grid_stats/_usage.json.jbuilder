json.time "#{stat['_id']['year']}-#{stat['_id']['month']}-#{stat['_id']['day']} #{stat['_id']['hour']}:#{stat['_id']['minute']}"
json.set! metric, stat[metric]