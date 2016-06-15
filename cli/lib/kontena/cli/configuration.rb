require 'json'

module Kontena
  module Cli
    class Configuration

      attr_accessor :settings

      MASTER_ENVS = {
        'KONTENA_TOKEN'             => 'token',
        'KONTENA_TOKEN_EXPIRES_AT'  => 'token_expires_at',
        'KONTENA_REFRESH_TOKEN'     => 'refresh_token',
        'KONTENA_URL'               => 'url',
        'KONTENA_GRID'              => 'grid',
        'KONTENA_AUTH_PROVIDER_URL' => 'auth_provider'
      }

      def initialize
        load_settings
      end

      def require_token!
        unless token
          raise ArgumentError.new("Please login first using: kontena login")
        end
      end

      def require_master!
        unless url
          raise ArgumentError.new("It seem's that you are not logged into Kontena master, please login with: kontena login")
        end
        ensure_custom_ssl_ca(url)
      end

      def require_current_grid!
        unless current_grid
          raise ArgumentError.new("Please select grid first using: kontena grid use <grid name>")
        end
      end

      def current_grid=(grid)
        settings['servers'][current_master_index]['grid'] = grid['id']
        update
      end

      def clear_current_grid
        settings['servers'][current_master_index].delete('grid')
        update
      end

      def token_expired?
        return true unless token_expires_at
        token_expires_at.to_i < Time.now.utc.to_i
      end

      def current_account
        settings['accounts'].find{|a| a['name'] == settings['current_account']}
      end

      def current_account=(account_name)
        account = find_account(account_name)
        if account
          settings['current_account'] = account['name']
          update
        end
      end

      def current_master=(server_name)
        server = find_server(server_name)['name']
        if server
          settings['current_server'] = server['name']
          settings['current_account'] = server['account']
          update
        end
      end

      def find_server(server_name)
        settings.fetch('servers', []).find{|server| server.fetch('name', '') == server_name}
      end

      def find_account(account_name)
        settings.fetch('accounts', []).find{|account| account.fetch('name', '') == account_name}
      end

      MASTER_ENVS.each do |env_key, master_key|
        define_method master_key.to_sym do
          ENV[env_key] || current_master[master_key]
        end

        define_method "#{master_key}=".to_sym do |value|
          current_master[master_key] = value
          update
        end
      end

      alias_method :current_grid, :grid

      def update_environment
        MASTER_ENVS.each do |env_key, master_key|
          ENV[env_key] = current_master[master_key]
        end
        true
      end

      def current_master
        index = current_master_index
        unless index
          raise ArgumentError.new("It seem's that you are not logged into ANY Kontena master, please login with: kontena login")
        end
        settings['servers'][index]
      end

      def add_master(server_name, master_info)
        server_name = server_name || 'default'
        index = settings['servers'].find_index{|m| m['name'] == server_name}
        if index
          settings['servers'][index] = master_info
        else
          settings['servers'] << master_info
        end
        settings['current_server'] = server_name
        update
      end

      def current_master_index
        current_server = settings['current_server'] || 'default'
        settings['servers'].find_index{|m| m['name'] == current_server}
      end

      def update(&block)
        yield self if block_given?
        write && update_environment
      end

      def reload_settings
        @settings = load_settings
      end

      def load_settings
        ENV["DEBUG"] && puts("Loading configuration '#{settings_filename}'")
        @settings = File.exists?(settings_filename) ? JSON.parse(File.read(settings_filename)) : default_settings
        server_settings_migrated  = migrate_server_settings
        account_settings_migrated = migrate_account_settings
        if server_settings_migrated || account_settings_migrated
         update
        end
        ENV["DEBUG"] && puts("Configuration loaded")
        @settings
      end

      # Move settings['servers'] auth data into settings['accounts'] and
      # replace with a refrerence to the account that was created
      # This will also expire all tokens.
      def migrate_account_settings
        return false if @settings.has_key?('accounts')
        ENV["DEBUG"] && puts("Migrating account settings")
        @settings['accounts'] = []

        @settings['servers'].reject!(&:empty?)

        @settings['servers'].map{|s| s['email']}.uniq.each do |email|
          @settings['accounts'] << {
            'name' => "kontena#{"-#{@settings['accounts'].size}" if @settings['accounts'].size > 0}",
            'url' => 'https://auth.kontena.io',
            'username' => @settings['servers'].last['email'],
            'token' => nil,
            'token_expires_at' => nil,
            'refresh_token' => nil
          }
        end

        @settings['servers'].map! do |server|
          server['account'] = @settings['accounts'].find{|a| a['username'] == server['email']}['name']
          server['account_authentication'] = false
          server.delete('email')
          server
        end

        @settings['current_account'] = 'kontena'
        true
      end

      def migrate_server_settings
        return false if @settings.has_key?('current_server')
        ENV["DEBUG"] && puts("Migrating server settings")
        # Migrate the old settings model to new
        @settings['server']['name'] = 'default'
        @settings = {
            'current_server' => 'default',
            'servers' => [ @settings['server']]
        }
        true
      end

      def default_settings
        ENV["DEBUG"] && puts("Config not readable, using default settings")
        {
          'current_server' => 'default',
          'current_account' => 'kontena',
          'servers' => [],
          'accounts' => []
        }
      end

      def settings_filename
        @settings_filename ||= File.join(Dir.home, '/.kontena_client.json')
      end

      def generate_json
        JSON.pretty_generate(
          settings.sort_by{|_, v| v.kind_of?(Enumerable) ? 1 : 0}.to_h
        )
      end

      # Write the settings as JSON, sorting fields with hash/array content to bottom
      def write
        ENV["DEBUG"] && puts("Writing configuration '#{settings_filename}'")
        File.write(settings_filename, generate_json)
      end

      def ensure_custom_ssl_ca
        return if Excon.defaults[:ssl_ca_file]

        uri = URI::parse(url)
        cert_file = File.join(Dir.home, "/.kontena/certs/#{uri.host}.pem")
        if File.exist?(cert_file)
          Excon.defaults[:ssl_ca_file] = cert_file
        end
      end

    end
  end
end
