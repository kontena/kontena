module Kontena::Cli::Vpn
  class ConfigCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    def execute
      require 'rbconfig'
      require_api_url
      payload = {cmd: ['/usr/local/bin/ovpn_getclient', 'KONTENA_VPN_CLIENT']}
      stdout, stderr = client(require_token).post("containers/#{current_grid}/vpn/vpn-1/exec", payload)
      if linux?
        stdout << "\n"
        stdout << "up /etc/openvpn/update-resolv-conf\n"
        stdout << "down /etc/openvpn/update-resolv-conf\n"
      end
      puts stdout
    end

    # @return [Boolean]
    def linux?
      host_os = RbConfig::CONFIG['host_os']
      host_os.include?('linux')
    end
  end
end
