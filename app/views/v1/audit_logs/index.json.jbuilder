json.logs @logs do |log|
  json.partial! 'app/views/v1/audit_logs/audit_log', log: log
end