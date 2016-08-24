require 'logger'
require_relative 'app/boot'
require_relative 'app/boot_jobs'
require_relative 'app/middlewares/token_authentication'
require_relative 'app/middlewares/client_version_restriction'
require 'bcrypt'

Dir[__dir__ + '/app/routes/v1/*.rb'].each {|file| require file }
require_relative 'app/routes/oauth2_api'
Dir[__dir__ + '/app/routes/oauth2/*.rb'].each {|file| require file }

Logger.class_eval { alias :write :'<<' }

class Server < Roda
  VERSION = File.read('./VERSION').strip

  if ENV['RACK_ENV'] == 'test'
    logger = nil
  else
    logger = Logger.new(STDOUT)
  end

  use Rack::CommonLogger, logger
  use ClientVersionRestriction, '0.15.0'

  use(
    TokenAuthentication, 
    exclude: [
      '/',
      '/v1/ping',
      '/v1/auth',
      '/cb',
      '/code',
      '/oauth2/token',
      '/v1/nodes',   #authorized using grid token
      '/v1/nodes/*'
    ],
    soft_exclude: [
      '/oauth2/authorize',
      '/authenticate'
    ],
    allow_expired: [
      '/authenticate' 
    ]
  )

  use Rack::Static, urls: { "/code" => "app/views/static/code.html" }

  # Accessor to global config. Defaults are loaded from config/defaults.yml.
  # Changing values in defaults.yml will not overwrite values in DB.
  def self.config
    return @config if @config
    @config = Configuration
    config_defaults.each do |key, value|
      if @config[key].nil?
        logger.debug "Setting configuration key '#{key}' using default '#{value}'"
        @config[key] = value
      end
    end
    @config
  end

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

  # Global logger
  def self.logger
    return @logger if @logger
    if ENV['RACK_ENV'] == 'test'
      @logger = Logger.new(File.open(File::NULL, "w"))
      @logger.level = Logger::UNKNOWN
    else
      @logger = Logger.new(STDOUT)
      @logger.progname = 'API'
      @logger.level = ENV["DEBUG"] ? Logger::DEBUG : Logger::INFO
    end
    @logger
  end

  # Read the defaults from config/defaults.yml
  def self.config_defaults
    defaults_file = Server.root.join('config/defaults.yml')
    if defaults_file.exist? && defaults_file.readable?
      logger.debug "Reading configuration defaults from #{defaults_file}"
      YAML.load(ERB.new(defaults_file.read).result)[ENV['RACK_ENV']] || {}
    else
      logger.debug "Configuration defaults #{defaults_file} not available"
      {}
    end
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

      r.on 'authorize' do
        r.run OAuth2Api::AuthorizationApi
      end
    end

    r.on 'v1' do
      r.on 'ping' do
        r.run V1::PingApi
      end

      r.on 'auth_provider' do
        r.run V1::AuthProviderApi
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
