
module Kontena::Cli::Volumes
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    requires_current_master
    requires_current_master_token

    def execute
      require 'tty-table'

      volumes = client.get("volumes/#{current_grid}")['volumes']
      table = TTY::Table.new ['NAME', 'SCOPE', 'DRIVER', 'CREATED AT'], volumes.map { |volume|
        [volume['name'], volume['scope'], volume['driver'], volume['created_at']]
      }
      puts table.render(:basic)
    end

  end
end
