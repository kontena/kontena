require 'excon'
require 'json'

module Kontena
  class PluginManager
    class RubygemsClient

      RUBYGEMS_URL = 'https://rubygems.org'
      HEADERS = {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }

      attr_reader :client

      def initialize
        @client = Excon.new(RUBYGEMS_URL)
      end

      def search(pattern = nil)
        response = client.get(
          path: "/api/v1/search.json?query=#{pattern}",
          headers: HEADERS
        )

        JSON.parse(response.body)
      end

      def versions(gem_name)
        response = client.get(
          path: "/api/v1/versions/#{gem_name}.json",
          headers: HEADERS
        )
        versions = JSON.parse(response.body)
        versions.map { |version| Gem::Version.new(version["number"]) }.sort.reverse
      end

    end
  end
end
