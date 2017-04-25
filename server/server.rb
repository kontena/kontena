require 'logger'
require 'pathname'

require_relative 'app/boot'
require_relative 'app/boot_jobs'
require_relative 'app/middlewares/filtered_logger'
require_relative 'app/middlewares/token_authentication'
require_relative 'app/middlewares/version_injector'
require_relative 'app/helpers/config_helper'

require_glob __dir__ + '/app/routes/*.rb'
require_glob __dir__ + '/app/routes/**/*.rb'

Logger.class_eval { alias :write :'<<' }

class Server < Roda
  VERSION = File.read('./VERSION').strip

  use FilteredLogger, Logging.logger
  use Rack::Attack
  use Rack::Static, urls: { "/code" => "app/views/static/code.html" }
  use TokenAuthentication, File.expand_path('../config/authentication.yml', __FILE__)
  use VersionInjector, VERSION

  include Logging
  include ConfigHelper

  # Path to server application root
  def self.root
    @root ||= Pathname.new(File.dirname(__FILE__))
  end

  # Service root url
  def self.root_url
    @url ||= config['server.root_url']
  end

  def self.name
    @name ||= config['server.name']
  end

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
      r.run V1::Api
    end

    r.on 'authenticate' do
      r.run OAuth2Api::AuthenticateApi
    end

    r.on 'cb' do
      r.run OAuth2Api::CallbackApi
    end

    r.on 'oauth2' do
      r.on 'token' do
        r.run OAuth2Api::TokenApi
      end

      r.on 'tokens' do
        r.run OAuth2Api::TokensApi
      end

      r.on 'authorize' do
        r.run OAuth2Api::AuthorizationApi
      end
    end

  end
end
