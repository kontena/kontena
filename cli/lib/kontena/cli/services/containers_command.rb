require_relative 'services_helper'

module Kontena::Cli::Services
  class ContainersCommand < Clamp::Command
    include Kontena::Cli::Common
    include ServicesHelper

    parameter "NAME", "Service name"

    def execute
      require_api_url
      token = require_token

      result = client(token).get("services/#{current_grid}/#{name}/containers")
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
