module Kontena::Cli::ExternalRegistries
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    def execute
      require_api_url
      require_current_grid
      token = require_token
      result = client(token).get("grids/#{current_grid}/external_registries")
      puts "%-30s %-20s %-30s" % ['Name', 'Username', 'Email']
      result['external_registries'].each { |r|
        puts "%-30.30s %-20.20s %-30.30s" % [r['name'], r['username'], r['email']]
      }
    end
  end
end
