module Kontena::Cli::Vpn
  class ConfigCommand < Kontena::Command
    include Kontena::Cli::GridOptions

    def execute
      require 'rbconfig'
      require_api_url
      payload = {cmd: ['/usr/local/bin/ovpn_getclient', 'KONTENA_VPN_CLIENT']}
      service = client(require_token).get("services/#{current_grid}/vpn/server/containers")['containers'][0]
      stdout, stderr = client(require_token).post("containers/#{service['id']}/exec", payload)
      if linux?
        stdout << "\n"
        stdout << "script-security 2 system\n"
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
