module Kontena::Cli::Vault
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    requires_current_master_token

    def execute
      result = client.get("grids/#{current_grid}/secrets")

      column_width_paddings = '%-54s %-25.25s %-25.25s'
      puts column_width_paddings % ['NAME', 'CREATED AT', 'UPDATED AT']
      result['secrets'].sort_by { |s| s['name'] }.each do |secret|
        puts column_width_paddings % [secret['name'], secret['created_at'], secret['updated_at']]
      end
    end
  end
end
