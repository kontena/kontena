module Kontena::Cli::Vpn
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common

    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    requires_current_master_token

    def execute
      confirm unless forced?
      name = 'vpn'
      vpn = client.get("services/#{current_grid}/#{name}") rescue nil
      exit_with_error("#{name} service does not exist") if vpn.nil?

      spinner "Removing #{vpn.colorize(:cyan)} service " do
        client.delete("services/#{current_grid}/vpn")
      end
    end
  end
end
