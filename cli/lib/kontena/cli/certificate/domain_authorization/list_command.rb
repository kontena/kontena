
module Kontena::Cli::Certificate::DomainAuthorization
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::TableGenerator::Helper
    include Kontena::Util

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def fields
      quiet? ? ['domain'] : {domain: 'domain', authorization_type: 'authorization_type', status: 'status'}
    end

    def execute
      authorizations = client.get("grids/#{current_grid}/domain_authorizations")['domain_authorizations']

      print_table(authorizations)
    end

  end
end
