require_relative 'common'

module Kontena::Cli::Plugins
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::TableGenerator::Helper
    include Common

    banner "List installed plugins"

    def fields
      quiet? ? [:name] : %i(name version description)
    end

    def plugins
      Kontena::PluginManager.instance.plugins.map do |plugin|
        {
          name: short_name(plugin.name),
          version: plugin.version,
          description: plugin.description
        }
      end
    end

    def execute
      print_table(plugins)
    end
  end
end
