require 'kontena/client'
require_relative '../common'
require 'pp'
module Kontena::Cli::Platform
  class Services
    include Kontena::Cli::Common

    def list
      require_api_url
      token = require_token

      grids = client(token).get("grids/#{current_grid}/services")
      grids['services'].each do |service|
        puts "#{service['id']} #{service['name']} #{service['image']}"
      end
    end

    def show(service_id)
      require_api_url
      token = require_token

      service = client(token).get("services/#{service_id}")
      pp service
    end

    def containers(service_id)
      require_api_url
      token = require_token

      result = client(token).get("services/#{service_id}/containers")
      result['containers'].each do |container|
        puts "#{container['name']} #{container['network_settings']['ip_address']} #{container['status']}"
      end
    end

    def logs(service_id)
      require_api_url
      token = require_token

      result = client(token).get("services/#{service_id}/container_logs")
      result['logs'].each do |log|
        puts log['data']
      end
    end

    def create(name, image, options)
      require_api_url
      token = require_token

      if options.ports
        ports = options.ports.map{|p|
          node_port, container_port = p.split(':')
          if node_port.nil? || container_port.nil?
            raise ArgumentError.new("Invalid port value #{p}")
          end
          {
            container_port: container_port,
            node_port: node_port
          }
        }
      end
      data = {
        name: name,
        image: image,
        stateful: !!options.stateful
      }
      data[:ports] = ports if options.ports
      data[:env] = options.env if options.env
      data[:container_count] = options.containers if options.containers
      data[:cmd] = options.cmd.split(" ") if options.cmd
      client(token).post("grids/#{current_grid}/services", data)
    end

    private
    def current_grid
      inifile['platform']['grid']
    end
  end
end
