module Kontena::Cli::Vpn
  class RemoveCommand < Clamp::Command
    include Kontena::Cli::Common

    option "--confirm", :flag, "Confirm remove", default: false, attribute_name: :confirmed

    def execute
      require_api_url
      token = require_token
      confirm unless confirmed?

      vpn = client(token).get("services/#{current_grid}/vpn") rescue nil
      abort("VPN service does not exist") if vpn.nil?

      client(token).delete("services/#{current_grid}/vpn")
    end
  end
end
