require 'logger'
require_relative 'app/boot'

Dir[__dir__ + '/app/routes/v1/*.rb'].each {|file| require file }
Logger.class_eval { alias :write :'<<' }

class Server < Roda
  logger = Logger.new(STDOUT)
  logger.level = (ENV['LOG_LEVEL'] || Logger::INFO).to_i
  use Rack::CommonLogger, logger

  route do |r|
    r.on 'v1' do
      r.on 'ping' do
        r.run V1::PingApi
      end

      r.post 'auth' do
        r.run V1::AuthApi
      end

      r.on('user') do
        r.run V1::UserApi
      end

      r.on('users') do
        r.run V1::UsersApi
      end

      r.on('grids') do
        r.run V1::GridsApi
      end

      r.on('services') do
        r.run V1::ServicesApi
      end

      r.on('containers') do
        r.run V1::ContainersApi
      end
    end
  end
end
