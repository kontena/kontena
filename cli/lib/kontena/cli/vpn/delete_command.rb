module Kontena::Cli::Vpn
  class DeleteCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    def execute
       puts "DEPRECATION WARNING: Support for 'kontena vpn delete' will be dropped. Use 'kontena vpn remove' instead.".colorize(:red)
      require_api_url
      token = require_token

      vpn = client(token).get("services/#{current_grid}/vpn") rescue nil
      abort("VPN service does not exist") if vpn.nil?

      client(token).delete("services/#{current_grid}/vpn")
    end
  end
end
