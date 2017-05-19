require_relative 'common'

module Kontena::Cli::Plugins
  class SearchCommand < Kontena::Command
    include Common

    parameter '[NAME]', 'Search text', completion: "PLUGIN_SEARCH"
    option '--pre', :flag, 'Include pre-release versions'

    option ['-q', '--quiet'], :flag, "Only list the identifying column", attribute_name: :quiet

    def execute
      results = Kontena::PluginManager.instance.search_plugins(name)
      exit_with_error("Cannot access plugin server") unless results
      puts "%-50s %-10s %-60s" % ['NAME', 'VERSION', 'DESCRIPTION'] unless quiet?
      results.each do |item|
        if pre?
          latest = Kontena::PluginManager.instance.latest_version(item['name'], pre: true)
          item['version'] = latest.version.to_s
        end
        if quiet?
          puts short_name(item['name'])
        else
          puts "%-50s %-10s %-60s" % [short_name(item['name']), item['version'], item['info']]
        end
      end
    end
  end
end
