require 'inifile'
require 'terminal-table'
require 'colorize'

module Kontena
  module Cli
    module Common
      def require_api_url
        api_url
      end

      def require_token
        token = inifile['server']['token']
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

      def ini_filename
        File.join(Dir.home, '/.kontena_client')
      end

      def inifile
        if @inifile.nil?
          if File.exists?(ini_filename)
            @inifile = IniFile.load(ini_filename)
          else
            @inifile = IniFile.new
          end
        end

        unless @inifile['kontena']
          @inifile['kontena'] = {}
        end

        @inifile
      end

      def api_url
        url = inifile['server']['url']
        unless url
          raise ArgumentError.new("Please init service first using: kontena connect")
        end
        url
      end

      def current_grid=(grid)
        inifile['server']['grid'] = grid['id']
        inifile.save(filename: ini_filename)
      end

      def clear_current_grid
        inifile['server'].delete('grid')
        inifile.save(filename: ini_filename)
      end

      def current_grid
        inifile['server']['grid']
      end

    end
  end
end
