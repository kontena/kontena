require 'colorize'
require 'uri'

module Kontena
  module Cli
    module Common
      def require_api_url
        api_url
      end

      def require_token
        token = ENV['KONTENA_TOKEN'] || settings['server']['token']
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
          else
            @settings = {'server' => {}}
          end
        end
        @settings
      end

      def api_url
        url = ENV['KONTENA_URL'] || settings['server']['url']
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
        settings['server']['grid'] = grid['id']
        save_settings
      end

      def require_current_grid
        if current_grid.nil?
          raise ArgumentError.new("Please select grid first using: kontena grid use <grid name>")
        end
      end

      def clear_current_grid
        settings['server'].delete('grid')
        save_settings
      end

      def current_grid
        ENV['KONTENA_GRID'] || settings['server']['grid']
      end

      def save_settings
        File.write(settings_filename, JSON.pretty_generate(settings))
      end
    end
  end
end
