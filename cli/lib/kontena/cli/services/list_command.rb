require_relative 'services_helper'

module Kontena::Cli::Services
  class ListCommand < Clamp::Command
    include Kontena::Cli::Common
    include ServicesHelper

    def execute
      require_api_url
      token = require_token

      grids = client(token).get("grids/#{current_grid}/services")
      titles = ['NAME', 'IMAGE', 'INSTANCES', 'STATEFUL', 'STATE']
      puts "%-30.30s %-50.50s %-10s %-8s %-10s" % titles
      grids['services'].each do |service|
        stateful = service['stateful'] ? 'yes' : 'no'
        image = service['image']
        if image.length > 50
          image = image[0..10] << '...' << image[-35..-1]
        end
        vars = [
          service['name'],
          image,
          service['container_count'],
          stateful,
          service['state']
        ]
        puts "%-30.30s %-50.50s %-10.10s %-8s %-10s" % vars
      end
    end
  end
end
