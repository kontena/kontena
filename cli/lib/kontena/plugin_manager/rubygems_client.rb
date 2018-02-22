require 'kontena_cli'
require 'json'
require 'uri'
require 'net/https'

module Kontena
  module PluginManager
    class RubygemsClient

      JSON_MIME  ='application/json'.freeze
      ACCEPT = 'Accept'.freeze
      HTTPOK = "200".freeze

      def search(pattern = nil)
        get('/api/v1/search.json', query: pattern)
      end

      def versions(gem_name)
        response = get("/api/v1/versions/#{gem_name}.json")
        response.map { |version| Gem::Version.new(version["number"]) }.sort.reverse
      end

      # Get the latest version number from rubygems
      # @param plugin_name [String]
      # @param pre [Boolean] include prerelease versions
      def latest_version(gem_name, pre: false)
        return versions(gem_name).first if pre
        versions(gem_name).find { |version| !version.prerelease? }
      end

      def client
        return @client if @client
        @client = Net::HTTP.new('rubygems.org', 443)
        @client.use_ssl = true
        @client
      end

      def request_path(path, query = nil)
        uri = URI(path)
        uri.query = URI.encode_www_form(query) if query
        uri.to_s
      end

      def get_request(path)
        request = Net::HTTP::Get.new(path)
        request[ACCEPT] = JSON_MIME
        request
      end

      def get(path, query = nil)
        Kontena.logger.debug { "Requesting GET #{path}" }
        response = client.request(get_request(request_path(path, query)))
        Kontena.logger.debug { "Response #{response.code}" }
        raise "Server responded with #{response.code} (#{response.class.name})" unless response.code == HTTPOK
        JSON.parse(response.body)
      end
    end
  end
end
