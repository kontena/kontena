
module Kontena::Cli::Plugins
  class ListCommand < Kontena::Command

    def execute
      titles = ['NAME', 'VERSION', 'DESCRIPTION']
      puts "%-40s %-10s %-40s" % titles
      Kontena::PluginManager.instance.plugins.each do |plugin|
        puts "%-40s %-10s %-40s" % [plugin.name, plugin.version, plugin.description]
      end
    end
  end
end
