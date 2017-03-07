
module Kontena::Cli::Volume
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions


    requires_current_master
    requires_current_master_token

    def execute
      volumes = client.get("volumes/#{current_grid}")['volumes']
      columns = '%-25.25s %-25.25s %-25.25s %-25.25s'
      puts columns % ['NAME', 'SCOPE', 'DRIVER', 'CREATED AT']
      volumes.each do |volume|
        puts columns % [volume['name'], volume['scope'], volume['driver'], volume['created_at']]
      end
    end

  end
end
