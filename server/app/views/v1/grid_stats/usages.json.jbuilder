json.stats @stats do |stat|
  json.partial! 'app/views/v1/terminal_stats/usage', stat: stat, metric: @metric
end
