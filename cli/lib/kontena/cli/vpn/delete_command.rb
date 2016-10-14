module Kontena::Cli::Vpn
  class DeleteCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    requires_current_master_token

    def execute
      warning "Support for 'kontena vpn delete' will be dropped. Use 'kontena vpn remove' instead."
      vpn = client.get("services/#{current_grid}/vpn") rescue nil
      abort("VPN service does not exist") if vpn.nil?
      client.delete("services/#{current_grid}/vpn")
    end
  end
end
