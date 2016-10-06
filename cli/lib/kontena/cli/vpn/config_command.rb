module Kontena::Cli::Vpn
  class ConfigCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    requires_current_master_token

    def execute
      require 'rbconfig'
      payload = {cmd: ['/usr/local/bin/ovpn_getclient', 'KONTENA_VPN_CLIENT']}
      stdout, stderr = client.post("containers/#{current_grid}/vpn/vpn-1/exec", payload)
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
