require 'kontena/client'
require_relative '../common'

module Kontena
  module Cli
    module Services
      module ServicesHelper
        include Kontena::Cli::Common

        # @param [String] token
        # @param [String] grid_id
        # @param [Hash] data
        def create_service(token, grid_id, data)
          client(token).post("grids/#{grid_id}/services", data)
        end

        # @param [String] token
        # @param [String] service_id
        # @param [Hash] data
        def update_service(token, service_id, data)
          param = parse_service_id(service_id)
          client(token).put("services/#{param}", data)
        end

        # @param [String] token
        # @param [String] service_id
        def get_service(token, service_id)
          param = parse_service_id(service_id)
          client(token).get("services/#{param}")
        end

        # @param [String] token
        # @param [String] service_id
        def show_service(token, service_id)
          service = get_service(token, service_id)
          grid = service['id'].split('/')[0]
          puts "#{service['id']}:"
          puts "  status: #{service['state'] }"
          puts "  stateful: #{service['stateful'] == true ? 'yes' : 'no' }"
          puts "  scaling: #{service['container_count'] }"
          puts "  image: #{service['image']}"
          puts "  dns: #{service['name']}.#{grid}.kontena.local"

          puts "  affinity: "
          service['affinity'].to_a.each do |a|
            puts "    - #{a}"
          end

          if service['cmd']
            puts "  cmd: #{service['cmd'].join(' ')}"
          else
            puts "  cmd: "
          end

          puts "  env: "
          service['env'].to_a.each{|e| puts "    - #{e}"}

          puts "  ports:"
          service['ports'].to_a.each do |p|
            puts "    - #{p['node_port']}:#{p['container_port']}/#{p['protocol']}"
          end

          puts "  volumes:"
          service['volumes'].to_a.each do |v|
            puts "    - #{v}"
          end

          puts "  volumes_from:"
          service['volumes_from'].to_a.each do |v|
            puts "    - #{v}"
          end

          puts "  links: "
          service['links'].to_a.each do |l|
            puts "    - #{l['alias']}"
          end

          puts "  cap_add:"
          service['cap_add'].to_a.each do |c|
            puts "    - #{c}"
          end

          puts "  cap_drop:"
          service['cap_drop'].to_a.each do |c|
            puts "    - #{c}"
          end

          puts "  containers:"
          result = client(token).get("services/#{parse_service_id(service_id)}/containers")
          result['containers'].each do |container|
            puts "    #{container['name']}:"
            puts "      rev: #{container['deploy_rev']}"
            puts "      node: #{container['node']['name']}"
            puts "      dns: #{container['name']}.#{grid}.kontena.local"
            puts "      ip: #{container['overlay_cidr'].split('/')[0]}"
            puts "      public ip: #{container['node']['public_ip']}"
            if container['status'] == 'unknown'
              puts "      status: #{container['status'].colorize(:yellow)}"
            else
              puts "      status: #{container['status']}"
            end
          end
        end

        # @param [String] token
        # @param [String] service_id
        # @param [Hash] data
        def deploy_service(token, service_id, data)
          param = parse_service_id(service_id)
          client(token).post("services/#{param}/deploy", data)
          print 'deploying '
          until client(token).get("services/#{param}")['state'] != 'deploying' do
            print '.'
            sleep 1
          end
          puts ' done'
          puts ''
        end

        # @param [String] token
        # @param [String] service_id
        def start_service(token, service_id)
          param = parse_service_id(service_id)
          client(token).post("services/#{param}/start", {})
        end

        # @param [String] token
        # @param [String] service_id
        def stop_service(token, service_id)
          param = parse_service_id(service_id)
          client(token).post("services/#{param}/stop", {})
        end

        # @param [String] token
        # @param [String] service_id
        def delete_service(token, service_id)
          param = parse_service_id(service_id)
          client(token).delete("services/#{param}")
        end

        # @param [String] service_id
        # @return [String]
        def parse_service_id(service_id)
          if service_id.to_s.include?('/')
            param = service_id
          else
            param = "#{current_grid}/#{service_id}"
          end
        end

        # @param [Array<String>] port_options
        # @return [Array<Hash>]
        def parse_ports(port_options)
          port_options.map{|p|
            node_port, container_port, protocol = p.split(':')
            if node_port.nil? || container_port.nil?
              raise ArgumentError.new("Invalid port value #{p}")
            end
            {
                container_port: container_port,
                node_port: node_port,
                protocol: protocol || 'tcp'
            }
          }
        end

        # @param [Array<String>] link_options
        # @return [Array<Hash>]
        def parse_links(link_options)
          link_options.map{|l|
            service_name, alias_name = l.split(':')
            if service_name.nil?
              raise ArgumentError.new("Invalid link value #{l}")
            end
            alias_name = service_name if alias_name.nil?
            {
                name: service_name,
                alias: alias_name
            }
          }
        end

        # @param [String] memory
        # @return [Integer]
        def parse_memory(memory)
          if memory.end_with?('k')
            memory.to_i * 1000
          elsif memory.end_with?('m')
            memory.to_i * 1000000
          elsif memory.end_with?('g')
            memory.to_i * 1000000000
          else
            memory.to_i
          end
        end

        # @param [String] image
        # @return [String]
        def parse_image(image)
          unless image.include?(":")
            image = "#{image}:latest"
          end
          image
        end
      end
    end
  end
end
