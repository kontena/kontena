module Kontena::Cli::Plugins
  class SearchCommand < Kontena::Command

    parameter '[NAME]', 'Search text'

    def execute
      results = fetch_plugins(name)
      abort("Cannot access plugin server") unless results
      puts "%-50s %-10s %-60s" % ['NAME', 'VERSION', 'DESCRIPTION']
      results.each do |item|
        name = item['name'].sub('kontena-plugin-', '')
        puts "%-50s %-10s %-60s" % [name, item['version'], item['info']]
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
