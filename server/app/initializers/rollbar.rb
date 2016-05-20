unless ENV['ROLLBAR_TOKEN'].to_s.empty?
  require 'rollbar'

  Rollbar.configure do |config|
    config.access_token = ENV['ROLLBAR_TOKEN']
    config.environment = ENV['ROLLBAR_ENVIRONMENT']
  end

  Celluloid.exception_handler { |ex| Rollbar.error(ex) }
end
