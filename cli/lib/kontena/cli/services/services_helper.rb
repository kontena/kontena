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
          if service['cmd']
            puts "  cmd: #{service['cmd'].join(' ')}"
          else
            puts "  cmd: -"
          end

          puts "  env: "
          if service['env']
            service['env'].each{|e| puts "    - #{e}"}
          end
          puts "  ports:"
          service['ports'].each do |p|
            puts "    - #{p['node_port']}:#{p['container_port']}/#{p['protocol']}"
          end
          puts "  links: "
          if service['links']
            service['links'].each do |l|
              puts "    - #{l['alias']}"
            end
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

        ##
        # parse given options to hash
        # @return [Hash]
        def parse_service_data_from_options
          data = {}
          data[:ports] = parse_ports(ports_list) if ports_list
          data[:links] = parse_links(link_list) if link_list
          data[:volumes] = volume_list if volume_list
          data[:volumes_from] = volumes_from_list if volumes_from_list
          data[:memory] = parse_memory(memory) if memory
          data[:memory_swap] = parse_memory(memory_swap) if memory_swap
          data[:cpu_shares] = cpu_shares if cpu_shares
          data[:affinity] = affinity_list if affinity_list
          data[:env] = env_list if env_list
          data[:container_count] = instances if instances
          data[:cmd] = cmd.split(" ") if cmd
          data[:user] = user if user
          data[:image] = image if image
          data[:cap_add] = cap_add_list if cap_add_list
          data[:cap_drop] = cap_drop_list if cap_drop_list
          data
        end
      end
    end
  end
end
