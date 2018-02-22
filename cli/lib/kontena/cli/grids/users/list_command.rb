require_relative '../common'

module Kontena::Cli::Grids::Users
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Grids::Common
    include Kontena::Cli::TableGenerator::Helper
    include Kontena::Cli::GridOptions

    requires_current_master

    def fields
      quiet? ? %w(email) : %w(email name)
    end

    def execute
      print_table(client.get("grids/#{current_grid}/users")['users'])
    end
  end
end
