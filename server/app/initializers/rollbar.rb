if ENV['ROLLBAR_TOKEN'].to_s != ''
  require 'rollbar'

  Rollbar.configure do |config|
    config.access_token = ENV['ROLLBAR_TOKEN']
  end

  Celluloid.exception_handler { |ex| Rollbar.error(ex) }
end
