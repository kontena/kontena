
module Kontena::Cli::Volumes
  class ListCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::TableGenerator::Helper

    option ['--[no-]long', '-l'], :flag, "Show full dates", default: !$stdout.tty?

    requires_current_master
    requires_current_master_token

    def volumes
      client.get("volumes/#{current_grid}")['volumes']
    end

    def fields
      quiet? ? ['name'] : %w(name scope driver created_at)
    end

    def execute
      print_table(volumes) do |row|
        next if long? || quiet?
        row['created_at'] = time_ago(row['created_at'])
      end
    end
  end
end
