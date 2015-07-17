require 'kontena/client'
require_relative '../common'

module Kontena
  module Cli
    module Services
      module ServicesHelper
        include Kontena::Cli::Common

        def create_service(token, grid_id, data)
          client(token).post("grids/#{grid_id}/services", data)
        end

        def update_service(token, service_id, data)
          client(token).put("services/#{current_grid}/#{service_id}", data)
        end

        def get_service(token, service_id)
          client(token).get("services/#{current_grid}/#{service_id}")
        end

        def deploy_service(token, service_id, data)
          client(token).post("services/#{current_grid}/#{service_id}/deploy", data)
          print 'deploying '
          until client(token).get("services/#{current_grid}/#{service_id}")['state'] != 'deploying' do
            print '.'
            sleep 1
          end
          puts ' done'
          puts ''
        end

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
