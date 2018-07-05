
module Kontena::Cli::Certificate::DomainAuthorization
  class RemoveAuthorizationCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "DOMAIN", "Domain authorization to remove"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced


    def execute
      confirm_command(self.domain) unless forced?

      require_api_url
      token = require_token


      spinner "Deleting domain authorization for #{self.domain.colorize(:cyan)}" do
        client.delete("domain_authorizations/#{current_grid}/#{self.domain}")
      end

    end

  end
end
