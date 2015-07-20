require 'logger'
require_relative 'app/boot'

Dir[__dir__ + '/app/routes/v1/*.rb'].each {|file| require file }
Logger.class_eval { alias :write :'<<' }

class Server < Roda
  if ENV['RACK_ENV'] == 'test'
    logger = nil
  else
    logger = Logger.new(STDOUT)
  end
  use Rack::CommonLogger, logger
  plugin :render, engine: 'jbuilder', ext: 'json.jbuilder', views: 'app/views/v1'

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

      r.on('nodes') do
        r.run V1::NodesApi
      end

      r.on('services') do
        r.run V1::ServicesApi
      end

      r.on('containers') do
        r.run V1::ContainersApi
      end

      r.on('external_registries') do
        r.run V1::ExternalRegistriesApi
      end
    end
  end
end
