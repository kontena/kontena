require_relative 'services_helper'

module Kontena::Cli::Services
  class ContainersCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"

    def execute
      require_api_url
      token = require_token

      result = client(token).get("services/#{current_grid}/#{name}/containers")
      result['containers'].each do |container|
        puts "#{container['id']}:"
        puts "  rev: #{container['deploy_rev']}"
        puts "  node: #{container['node']['name']}"
        puts "  dns: #{container['name']}.#{current_grid}.kontena.local"
        puts "  ip: #{container['overlay_cidr'].to_s.split('/')[0]}"
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
