module Kontena::Cli::Vault
  class ListCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::TableGenerator::Helper

    option '--return', :flag, "Return the keys", hidden: true
    option ['--[no-]long', '-l'], :flag, "Show full dates", default: !$stdout.tty?

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def secrets
      client.get("grids/#{current_grid}/secrets")['secrets'].sort_by { |s| s['name'] }
    end

    def fields
      return['name'] if quiet?
      %w(name created_at updated_at)
    end

    def execute
      return secrets.map { |s| s['name'] } if return?
      print_table(secrets) do |row|
        next if quiet? || long?
        row['updated_at'] = updated?(row) ? pastel.blue('never') : time_ago(row['updated_at'])
        row['created_at'] = time_ago(row['created_at'])
      end
    end

    def updated?(row)
      row['created_at'] == row['updated_at']
    end
  end
end
