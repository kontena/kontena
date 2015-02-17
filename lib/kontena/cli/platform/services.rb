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
        puts "#{service['id']} #{service['image']}"
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
        puts "#{container['id']}:"
        puts "  node: #{container['node']['name']}"
        puts "  ip (internal): #{container['network_settings']['ip_address']}"
        puts "  status: #{container['status']}"
        puts ""
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

    def deploy(service_id)
      require_api_url
      token = require_token

      result = client(token).post("services/#{service_id}/deploy", {})
    end

    def create(name, image, options)
      require_api_url
      token = require_token

      if options.ports
        ports = parse_ports(options.ports)
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

    def update(service_id, options)
      require_api_url
      token = require_token

      data = {}
      data[:env] = options.env if options.env
      data[:container_count] = options.containers if options.containers
      data[:cmd] = options.cmd.split(" ") if options.cmd
      data[:ports] = parse_ports(options.ports) if options.ports

      client(token).put("services/#{service_id}", data)
    end

    def destroy(service_id)
      require_api_url
      token = require_token

      result = client(token).delete("services/#{service_id}")
    end

    private

    def current_grid
      inifile['platform']['grid']
    end

    def parse_ports(port_options)
      port_options.map{|p|
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
  end
end
