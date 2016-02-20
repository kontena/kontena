require 'colorize'
require 'uri'

module Kontena
  module Cli
    module Common
      def require_api_url
        api_url
      end

      def require_token
        token = ENV['KONTENA_TOKEN'] || current_master['token']
        unless token
          raise ArgumentError.new("Please login first using: kontena login")
        end
        token
      end

      def client(token = nil)
        if @client.nil?
          headers = {}
          unless token.nil?
            headers['Authorization'] = "Bearer #{token}"
          end

          @client = Kontena::Client.new(api_url, headers)
        end
        @client
      end

      def reset_client
        @client = nil
      end

      def settings_filename
        File.join(Dir.home, '/.kontena_client.json')
      end

      def settings
        if @settings.nil?
          if File.exists?(settings_filename)
            @settings = JSON.parse(File.read(settings_filename))
            unless @settings['current_server']
              # Let's migrate the old settings model to new
              @settings['server']['name'] = 'default'
              @settings = {
                  'current_server' => 'default',
                  'servers' => [ @settings['server']]
              }
              save_settings
            end
          else
            @settings = {
                'current_server' => 'default',
                'servers' => [{}]
            }
          end
        end
        @settings
      end

      def api_url
        url = ENV['KONTENA_URL'] || current_master['url']
        unless url
          raise ArgumentError.new("It seem's that you are not logged into Kontena master, please login with: kontena login")
        end
        ensure_custom_ssl_ca(url)
        url
      end

      def ensure_custom_ssl_ca(url)
        return if Excon.defaults[:ssl_ca_file]

        uri = URI::parse(url)
        cert_file = File.join(Dir.home, "/.kontena/certs/#{uri.host}.pem")
        if File.exist?(cert_file)
          Excon.defaults[:ssl_ca_file] = cert_file
        end
      end

      def current_grid=(grid)
        settings['servers'][current_master_index]['grid'] = grid['id']
        save_settings
      end

      def require_current_grid
        if current_grid.nil?
          raise ArgumentError.new("Please select grid first using: kontena grid use <grid name>")
        end
      end

      def clear_current_grid
        settings['servers'][current_master_index].delete('grid')
        save_settings
      end

      def current_grid
        if self.respond_to?(:grid)
          ENV['KONTENA_GRID'] || grid || current_master['grid']
        else
          ENV['KONTENA_GRID'] || current_master['grid']
        end
      end

      def current_master_index
        current_server = settings['current_server'] || 'default'
        settings['servers'].find_index{|m| m['name'] == current_server}
      end

      def current_master
        index = current_master_index
        unless index
          raise ArgumentError.new("It seem's that you are not logged into ANY Kontena master, please login with: kontena login")
        end
        settings['servers'][index]
      end

      def current_master=(master_alias)
        settings['current_server'] = master_alias
        save_settings
      end

      def api_url=(api_url)
        settings['servers'][current_master_index]['url'] = api_url
        save_settings
      end

      def access_token=(token)
        settings['servers'][current_master_index]['token'] = token
        save_settings
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
        save_settings
      end

      def save_settings
        File.write(settings_filename, JSON.pretty_generate(settings))
      end
    end
  end
end
