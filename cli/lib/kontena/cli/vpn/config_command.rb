module Kontena::Cli::Vpn
  class ConfigCommand < Clamp::Command
    include Kontena::Cli::Common

    def execute
      require_api_url
      payload = {cmd: ['/usr/local/bin/ovpn_getclient', 'KONTENA_VPN_CLIENT']}
      stdout, stderr = client(require_token).post("containers/#{current_grid}/vpn/vpn-1/exec", payload)
      puts stdout
    end
  end
end
