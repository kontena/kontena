module Kontena::Cli::Vpn
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      token = require_token
      confirm unless forced?
      name = 'vpn'

      vpn = client(token).get("stacks/#{current_grid}/#{name}") rescue nil
      exit_with_error("VPN stack does not exist") if vpn.nil?

      spinner "Removing #{pastel.cyan(name)} service " do
        client(token).delete("stacks/#{current_grid}/#{name}")
      end
    end
  end
end
