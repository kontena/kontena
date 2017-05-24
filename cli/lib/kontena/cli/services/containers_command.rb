require_relative 'services_helper'

module Kontena::Cli::Services
  class ContainersCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "SERVICE_NAME", "Service name", attribute_name: :name

    def execute
      require_api_url
      token = require_token

      result = client(token).get("services/#{parse_service_id(name)}/containers")
      result['containers'].each do |container|
        puts "#{container['name']}:"
        puts "  rev: #{container['deploy_rev']}"
        puts "  node: #{container['node']['name']}"
        puts "  dns: #{container['hostname']}.#{container['domainname']}"
        puts "  ip: #{container['ip_address']}"
        puts "  public ip: #{container['node']['public_ip']}"
        if container['status'] == 'unknown'
          puts "  status: #{container['status'].colorize(:yellow)}"
        else
          puts "  status: #{container['status']}"
        end
        puts ""
      end
    end
  end
end
