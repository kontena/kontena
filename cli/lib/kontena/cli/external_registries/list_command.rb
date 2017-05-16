require 'tty-table'

module Kontena::Cli::ExternalRegistries
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::TableGenerator::Helper

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def fields
      quiet? ? %(name) : %w(name username email)
    end

    def external_registries
      client.get("grids/#{current_grid}/external_registries")['external_registries']
    end

    def execute
      print_table(external_registries)
    end
  end
end
