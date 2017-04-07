json.logs event_logs do |event_log|
  json.partial! 'app/views/v1/event_logs/event_log', event_log: event_log
end
