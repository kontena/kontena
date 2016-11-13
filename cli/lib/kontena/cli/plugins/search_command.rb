require_relative 'common'

module Kontena::Cli::Plugins
  class SearchCommand < Kontena::Command
    include Common

    parameter '[NAME]', 'Search text'

    def execute
      results = fetch_plugins(name)
      exit_with_error("Cannot access plugin server") unless results
      puts "%-50s %-10s %-60s" % ['NAME', 'VERSION', 'DESCRIPTION']
      results.each do |item|
        puts "%-50s %-10s %-60s" % [short_name(item['name']), item['version'], item['info']]
      end
    end

    def fetch_plugins(name)
      client = Excon.new('https://rubygems.org')
      response = client.get(
        path: "/api/v1/search.json?query=kontena-plugin-#{name}",
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }
      )

      JSON.parse(response.body) rescue nil
    end
  end
end
