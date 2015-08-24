require_relative 'services_helper'

module Kontena::Cli::Services
  class ListCommand < Clamp::Command
    include Kontena::Cli::Common
    include ServicesHelper

    def execute
      require_api_url
      token = require_token

      grids = client(token).get("grids/#{current_grid}/services")
      puts "%-30.30s %-40.40s %-10s %-8s" % ['NAME', 'IMAGE', 'INSTANCES', 'STATEFUL']
      grids['services'].each do |service|
        state = service['stateful'] ? 'yes' : 'no'
        puts "%-30.30s %-40.40s %-10.10s %-8s" % [service['name'], service['image'], service['container_count'], state]
      end
    end
  end
end
