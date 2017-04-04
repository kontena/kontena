require 'ostruct'
require 'singleton'
require 'forwardable'
require 'json'
require 'logger'

module Kontena
  module Cli
    # Helper to access and update the CLI configuration file.
    #
    # Also provides a "fake" config hash that behaves just like the file based
    # config when ENV-variables are used instead of config file.
    class Config < OpenStruct
      include Singleton

      attr_accessor :logger
      attr_accessor :current_server
      attr_reader :current_account

      def self.reset_instance
        Singleton.send :__init__, self
        self
      end

      TokenExpiredError = Class.new(StandardError)

      def initialize
        super
        @logger = Logger.new(ENV["DEBUG"] ? $stderr : $stdout)
        @logger.level = ENV["DEBUG"].nil? ? Logger::INFO : Logger::DEBUG
        @logger.progname = 'CONFIG'
        load_settings_from_env || load_settings_from_config_file

        logger.debug "Configuration loaded with #{servers.count} servers."
        logger.debug "Current master: #{current_server || '(not selected)'}"
        logger.debug "Current grid: #{current_grid || '(not selected)'}"
      end

      # Craft a regular looking configuration based on ENV variables
      def load_settings_from_env
        return nil unless ENV['KONTENA_URL']
        logger.debug 'Loading configuration from ENV'
        servers << Server.new(
          url: ENV['KONTENA_URL'],
          name: 'default',
          token: Token.new(access_token: ENV['KONTENA_TOKEN'], parent_type: :master, parent_name: 'default'),
          grid: ENV['KONTENA_GRID'],
          parent_type: :master,
          parent_name: 'default'
        )
        accounts << Account.new(
          url: ENV['AUTH_API_URL'] || 'https://auth.kontena.io',
          name: 'kontena',
          token: Token.new(access_token: ENV['KONTENA_ACCOUNT_TOKEN'], parent_type: :account, parent_name: 'default')
        )

        self.current_master  = 'default'
        self.current_account = 'kontena'
      end

      def extract_token!(hash={})
        Token.new(
          access_token: hash.delete('token'),
          refresh_token: hash.delete('refresh_token'),
          expires_at: hash.delete('token_expires_at').to_i
        )
      end

      # Load configuration from default location ($HOME/.kontena_client.json)
      def load_settings_from_config_file
        settings = config_file_available? ? parse_config_file : default_settings

        Array(settings['servers']).each do |server_data|
          if server_data['token']
            token = extract_token!(server_data)
            token.parent_type = :master
            token.parent_name = server_data['name']
            server = Server.new(server_data)
            server.token = token
          else
            server = Server.new(server_data)
          end
          server.account ||= 'master'
          if servers.find { |s| s['name'] == server.name}
            server.name = "#{server.name}-2"
            server.name.succ! until servers.find { |s| s['name'] == server.name }.nil?
            logger.debug "Renamed server to #{server.name} because a duplicate was found in config"
          end
          servers << server
        end

        self.current_server = ENV['KONTENA_MASTER'] || settings['current_server']

        Array(settings['accounts']).each do |account_data|
          if account_data['token']
            token = extract_token!(account_data)
            token.parent_type = :account
            token.parent_name = account_data['name']
            account = Account.new(account_data)
            account.token = token
          else
            account = Account.new(account_data)
          end
          accounts << account
        end

        ka = find_account('kontena')
        if ka
          kontena_account_data.each {|k,v| ka[k] = v}
        else
          accounts << Account.new(kontena_account_data)
        end

        master_index = find_account_index('master')
        accounts.delete_at(master_index) if master_index
        accounts << Account.new(master_account_data)

        self.current_account = settings['current_account'] || 'kontena'
      end

      def kontena_account_data
        {
          name: 'kontena',
          url: 'https://cloud-api.kontena.io',
          stacks_url: 'https://stacks.kontena.io',
          token_endpoint: 'https://cloud-api.kontena.io/oauth2/token',
          authorization_endpoint: 'https://cloud.kontena.io/login/oauth/authorize',
          userinfo_endpoint: 'https://cloud-api.kontena.io/user',
          token_post_content_type: 'application/x-www-form-urlencoded',
          code_requires_basic_auth: false,
          token_method: 'post',
          scope: 'user',
          client_id: nil
        }
      end

      def master_account_data
        {
          name: 'master',
          token_endpoint: '/oauth2/token',
          authorization_endpoint: '/oauth2/authorize',
          userinfo_endpoint: '/v1/user',
          token_post_content_type: 'application/json',
          token_method: 'post',
          code_requires_basic_auth: false
        }
      end

      # Verifies access to existing configuration file
      #
      # @return [Boolean]
      def config_file_available?
        File.exist?(config_filename) && File.readable?(config_filename)
      end

      # Default settings hash, used when configuration file does not exist.
      #
      # @return [Hash]
      def default_settings
        logger.debug 'Configuration file not found, using default settings.'
        {
          'current_server' => 'default',
          'servers' => []
        }
      end

      # Converts old style settings hash into modern one
      #
      # @param [Hash] settings_hash
      # @return [Hash] migrated_settings_hash
      def migrate_legacy_settings(settings)
        logger.debug "Migrating from legacy style configuration"
        {
          'current_server' => 'default',
          'servers' => [
            settings['server'].merge(
              'name' => 'default',
              'account' => 'kontena'
            )
          ],
          'accounts' => [ kontena_account_data ]
        }
      end

      # Read, parse and migrate the configuration file
      #
      # @return [Hash] config_data
      def parse_config_file
        logger.debug "Loading configuration from #{config_filename}"
        settings = JSON.load(File.read(config_filename))
        if settings.has_key?('server')
          settings = migrate_legacy_settings(settings)
        else
          settings
        end
      end

      # Return the configuration file path. You can override the default
      # by using KONTENA_CONFIG environment variable.
      #
      # @return [String] path
      def config_filename
        @config_filename ||= ENV['KONTENA_CONFIG'] || default_config_filename
      end

      # Generate the default configuration filename
      def default_config_filename
        File.join(Dir.home, '.kontena_client.json')
      end

      # List of configured servers
      #
      # @return [Array]
      def servers
        @servers ||= []
      end

      # List of configured accounts
      #
      # @return [Array]
      def accounts
        @accounts ||= []
      end

      # Add a new server to the configuration
      #
      # @param [Hash] server_data
      def add_server(data)
        token = Token.new(
          access_token: data.delete('token'),
          refresh_token: data.delete('refresh_token'),
          expires_at: data.delete('token_expires_at'),
          parent_type: :master,
          parent_name: data['name'] || data[:name]
        )
        server = Server.new(data.merge(token: token))
        if (existing_index = find_server_index(server.name))
          servers[existing_index] = server
        else
          servers << server
        end
        write
      end

      # Search the server list for a server by field(s) and value(s).
      # @example
      #   find_server_by(url: 'https://localhost', token: 'abcd')
      # @param [Hash] search_criteria
      # @return [Server, NilClass]
      def find_server_by(criteria = {})
        servers.find{|s| criteria.none? {|k,v| v != s[k]}}
      end

      # Search the server list for a server by field(s) and value(s)
      # and return its index.
      #
      # @example
      #   find_server_index(url: 'https://localhost')
      # @param [Hash] search_criteria
      # @return [Fixnum, NilClass]
      def find_server_index_by(criteria = {})
        servers.find_index{|s| criteria.none? {|k,v| v != s[k]}}
      end

      # Shortcut to find_server_by(name: name)
      #
      # @param [String] server_name
      # @return [Server, NilClass]
      def find_server(name)
        find_server_by(name: name)
      end

      # Shortcut to find_server_index_by(name: name)
      #
      # @param [String] server_name
      # @return [Fixnum, NilClass]
      def find_server_index(name)
        find_server_index_by(name: name)
      end

      def find_account(name)
        accounts.find{|a| a['name'] == name.to_s}
      end

      def find_account_index(name)
        accounts.find_index{|a| a['name'] == name.to_s}
      end

      # Currently selected master's configuration data
      #
      # @return [Server]
      def current_master
        return servers[@current_master_index] if @current_master_index
        return nil unless current_server
        @current_master_index = find_server_index(current_server)
        servers[@current_master_index] if @current_master_index
      end

      # Raises unless current master has token.
      #
      # @return [Token] current_master_token
      # @raise [ArgumentError] if no token available
      def require_current_master_token
        require_current_master
        token = current_master.token
        if token && token.access_token
          return token unless token.expired?
          raise TokenExpiredError, "The access token has expired and needs to be refreshed."
        end
        raise ArgumentError, "You are not logged into a Kontena Master. Use: kontena master login"
      end

      # Raises unless current master is selected.
      #
      # @return [Server] current_master
      # @raise [ArgumentError] if no account is selected
      def require_current_master
        return current_master if current_master
        raise ArgumentError, "You are not logged into a Kontena Master. Use: kontena master login"
      end

      # Raises unless current account is selected.
      #
      # @return [Account] current_account
      # @raise [ArgumentError] if no account is selected
      def require_current_account
        return @current_account if @current_account
        raise ArgumentError, "You are not logged into an authorization provider. Use: kontena cloud login"
      end

      def require_current_account_token
        account = require_current_account
        if !account || account.token.nil? || account.token.access_token.nil?
          raise ArgumentError, "You are not logged in to Kontena Cloud. Use: kontena cloud login"
        elsif account.token.expired?
          raise TokenExpiredError, "The cloud access token has expired and needs to be refreshed." unless cloud_client.refresh_token
        end
      end

      # Set the current master.
      #
      # @param [String] server_name
      # @raise [ArgumentError] if server by that name doesn't exist
      def current_master=(name)
        @current_master_index = nil
        if name.nil?
          self.current_server = nil
        else
          index = find_server_index(name.respond_to?(:name) ? name.name : name)
          if index
            self.current_server = servers[index].name
          else
            raise ArgumentError, "Server '#{name}' does not exist, can't add as current master."
          end
        end
      end

      # Raises unless current grid is selected.
      #
      # @return [String] current_grid_name
      # @raise [ArgumentError] if no grid is selected
      def require_current_grid
        return current_grid if current_grid
        raise ArgumentError, "You have not selected a grid. Use: kontena grid"
      end

      # Name of the currently selected grid. Can override using
      # KONTENA_GRID environment variable.
      #
      # @return [String, NilClass]
      def current_grid
        ENV['KONTENA_GRID'] || (current_master && current_master.grid)
      end

      # Set the current grid name.
      #
      # @param [String] grid_name
      # @raise [ArgumentError] if current master hasn't been selected
      def current_grid=(name)
        if current_master
          current_master.grid = name
        else
          raise ArgumentError, "Current master not selected, can't set grid."
        end
      end

      def current_account=(name)
        if name.nil?
          @current_account = nil
        elsif name == 'master'
          raise ArgumentError, "The master account can not be used as current account."
        else
          account = find_account(name.respond_to?(:name) ? name.name : name)
          if account
            @current_account = account
          else
            raise ArgumentError, "Account '#{name}' not found in configuration"
          end
        end
      end

      # Returns a cleaned up version of the kontena account data with only the token and name.
      def kontena_account_hash
        hash = { name: 'kontena' }
        acc  = find_account('kontena')
        if acc && acc.token
          hash[:username] = acc.username if acc.username
          hash.merge!(acc.token.to_h)
        end
        hash
      end

      # Generate a hash from the current configuration.
      #
      # @return [Hash]
      def to_hash
        hash = {
          current_server: (self.current_server && find_server(self.current_server)) ? self.current_server : nil,
          current_account: self.current_account ? self.current_account.name : nil,
          servers: servers.map(&:to_h),
          accounts: accounts.reject{|a| a.name == 'master' || a.name == 'kontena'}.map(&:to_h) + [kontena_account_hash]
        }
        hash[:servers].each do |server|
          server.delete(:account) if server[:account] == 'master'
        end
        hash
      end

      # Generate a JSON string from the current configuration
      #
      # @return [String]
      def to_json
        JSON.pretty_generate(to_hash)
      end

      # Write the current configuration to config file.
      # Does nothing if using settings from environment variables.
      def write
        return nil if ENV['KONTENA_URL']
        logger.debug "Writing configuration to #{config_filename}"
        File.write(config_filename, to_json)
      end

      class << self
        extend Forwardable
        def_delegators :instance, *Config.instance_methods(false)
      end

      module TokenSerializer
        # Modified to_h to handle token data serialization
        #
        # @return [Hash]
        def to_h
          token = delete_field(:token) if respond_to?(:token)
          result = super
          if token
            self.token = token
            result.merge!(token.to_h)
          end
          result
        end
      end

      module ConfigurationInstance
        def config
          Kontena::Cli::Config.instance
        end
      end

      class Account < OpenStruct
        include TokenSerializer
        include ConfigurationInstance

        # Strip token info from master-account, the token is saved with the server.
        def to_h
          if self.name == 'master'
            super.to_h.reject do |k,_|
              [:url, :token, :refresh_token, :token_expires_at].include?(k)
            end
          else
            super
          end
        end
      end

      class Server < OpenStruct
        include TokenSerializer
        include ConfigurationInstance

        def initialize(*args)
          super
          @table[:account] ||= 'master'
        end
      end

      class Token < OpenStruct
        include ConfigurationInstance

        # Hash representation of token data
        #
        # @return [Hash]
        def to_h
          {
            token: self.access_token,
            token_expires_at: self.expires_at,
            refresh_token: self.refresh_token
          }.merge(self.respond_to?(:username) ? {username: self.username} : {})
        end

        def expires?
          expires_at.nil? ? false : expires_at.to_i > 0
        end

        def expired?
          expires? && expires_at && expires_at.to_i < Time.now.utc.to_i
        end

        def account
          return @account if @account
          return config.find_account('master') unless parent
          @account =
            case parent_type
            when :master then config.find_account(parent.account)
            when :account then parent
            else
              nil
            end
        end

        def parent
          return nil unless parent_type
          return nil unless parent_name
          case parent_type
          when :master
            config.find_server(parent_name)
          when :account
            config.find_account(parent_name)
          else
            nil
          end
        end
      end
    end
  end
end
