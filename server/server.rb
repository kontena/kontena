require 'logger'
require_relative 'app/boot'
require_relative 'app/boot_jobs'

Dir[__dir__ + '/app/routes/v1/*.rb'].each {|file| require file }
Logger.class_eval { alias :write :'<<' }

class Server < Roda
  VERSION = File.read('./VERSION').strip

  if ENV['RACK_ENV'] == 'test'
    logger = nil
  else
    logger = Logger.new(STDOUT)
  end
  use Rack::CommonLogger, logger
  plugin :json

  route do |r|

    r.root do
      {
        name: 'Kontena Master',
        tagline: 'The Container Platform',
        version: VERSION
      }
    end

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

      r.on('etcd') do
        r.run V1::EtcdApi
      end

      r.on('secrets') do
        r.run V1::SecretsApi
      end

      r.on('stacks') do
        r.run V1::StacksApi
      end

      r.on('certificates') do
        r.run V1::CertificatesApi
      end
    end
  end
end
