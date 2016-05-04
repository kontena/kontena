module Kontena::Cli::Vault
  class ListCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    def execute
      require_api_url
      token = require_token
      result = client(token).get("grids/#{current_grid}/secrets")

      column_width_paddings = '%-54s %-25.25s'
      puts column_width_paddings % ['NAME', 'CREATED AT']
      result['secrets'].sort_by { |s| s['name'] }.each do |secret|
        puts column_width_paddings % [secret['name'], secret['created_at']]
      end
    end
  end
end
