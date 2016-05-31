require 'shell-spinner'

module Kontena
  module Machine
    module Upcloud
      class NodeRestarter
        include RandomName
        include UpcloudCommon

        attr_reader :username, :password

        # @param [String] upcloud_username Upcloud username
        # @param [String] upcloud_password Upcloud password
        def initialize(upcloud_username, upcloud_password)
          @username = upcloud_username
          @password = upcloud_password
        end

        def run!(name)
          servers = get('server')
          unless servers && servers.has_key?(:servers)
            abort('Upcloud API error')
          end

          server = servers[:servers][:server].find{|s| s[:hostname] == name}

          if server
            ShellSpinner "Restarting Upcloud node #{name.colorize(:cyan)} " do
              result = post(
                "server/#{server[:uuid]}/restart", body: {
                  restart_server: {
                    stop_type: 'soft',
                    timeout: 600,
                    timeout_action: 'ignore'
                  }
                }.to_json
              )
            end
          else
            abort "Cannot find node #{name.colorize(:cyan)} in Upcloud"
          end
        end
      end
    end
  end
end

