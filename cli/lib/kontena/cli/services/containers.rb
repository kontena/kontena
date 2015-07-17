require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Services
  class Containers
    include Kontena::Cli::Common

    ##
    # @param [String] service_id
    def list(service_id)
      require_api_url
      token = require_token

      result = client(token).get("services/#{current_grid}/#{service_id}/containers")
      result['containers'].each do |container|
        puts "#{container['id']}:"
        puts "  node: #{container['node']['name']}"
        puts "  ip (internal): #{container['network_settings']['ip_address']}"
        puts "  status: #{container['status']}"
        puts ""
      end
    end
  end
end
