module Kontena::Cli::Vault
  class ListCommand < Clamp::Command
    include Kontena::Cli::Common

    def execute
      require_api_url
      token = require_token
      result = client(token).get("grids/#{current_grid}/secrets")
      puts '%-30.30s %-30.30s' % ['NAME', 'CREATED AT']
      result['secrets'].each do |secret|
        puts '%-30.30s %-30.30s' % [secret['name'], secret['created_at']]
      end
    end
  end
end
