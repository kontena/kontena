require 'json'
require 'yaml'

module Kontena::Cli::Master::AuthProvider
  class ShowCommand < Clamp::Command

    include Kontena::Cli::Common

    option ['-j', '--json'], :flag, "Output JSON"
    option ['-y', '--yaml'], :flag, "Output YAML"

    def execute
      require_current_master
      client = Kontena::Client.new(current_master.url, current_master.token)
      response = client.get('/v1/auth_provider')
      if response && response.kind_of?(Hash) && !response.has_key?('error')
        if self.json?
          puts JSON.pretty_generate(response)
        elsif self.yaml?
          puts YAML.dump(response)
        else
          puts "Authentication provider settings for master '#{current_master.name}' at #{current_master.url}"
          puts
          response.sort.to_h.each do |key, value|
            puts "  #{key.ljust(30)} : #{value}"
          end
        end
      else
        puts "Received error from server. #{response.last_response.body}"
        exit 1
      end
    end
  end
end
