require 'logger'
require 'pathname'

require_relative 'app/boot'
require_relative 'app/boot_jobs'
require_relative 'app/middlewares/token_authentication'
require_relative 'app/helpers/config_helper'

Dir[__dir__ + '/app/routes/*.rb'].each {|file| require file }
Dir[__dir__ + '/app/routes/**/*.rb'].each {|file| require file }

Logger.class_eval { alias :write :'<<' }

class Server < Roda
  VERSION = File.read('./VERSION').strip

  use Rack::CommonLogger, Logging.logger
  use Rack::Attack
  use Rack::Static, urls: { "/code" => "app/views/static/code.html" }
  use TokenAuthentication, File.expand_path('../config/authentication.yml', __FILE__)

  include Logging
  include ConfigHelper

  # Path to server application root
  def self.root
    @root ||= Pathname.new(File.dirname(__FILE__))
  end

  # Service root url
  def self.root_url
    @url ||= config[:root_url]
  end

  def self.name
    @name ||= config[:server_name]
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

    r.on 'v1', proc { r.run V1::Api }

    r.on 'authenticate', proc { r.run OAuth2Api::AuthenticateApi }
    r.on 'cb', proc { r.run OAuth2Api::CallbackApi }
    r.on 'oauth2' do
      r.on 'token', proc { r.run OAuth2Api::TokenApi }
      r.on 'authorize', proc { r.run OAuth2Api::AuthorizationApi } 
    end

  end
end
