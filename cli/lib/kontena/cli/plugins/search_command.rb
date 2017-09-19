require_relative 'common'
require 'kontena/plugin_manager'

module Kontena::Cli::Plugins
  class SearchCommand < Kontena::Command
    include Common
    include Kontena::PluginManager::Common

    parameter '[NAME]', 'Search text'
    option '--pre', :flag, 'Include pre-release versions'

    def execute
      results = search_plugins(name)
      exit_with_error("Cannot access plugin server") unless results
      puts "%-50s %-10s %-60s" % ['NAME', 'VERSION', 'DESCRIPTION']
      results.each do |item|
        if pre?
          latest = rubygems_client.latest_version(item['name'], pre: true)
          item['version'] = latest.version.to_s
        end
        puts "%-50s %-10s %-60s" % [short_name(item['name']), item['version'], item['info']]
      end
    end
  end
end
