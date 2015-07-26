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
      end
    end
  end
end
