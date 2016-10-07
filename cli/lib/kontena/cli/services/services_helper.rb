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
        # @param [Integer] instances
        def scale_service(token, service_id, instances)
          param = parse_service_id(service_id)
          client(token).post("services/#{param}/scale", {instances: instances})
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
          puts "  image: #{service['image']}"
          puts "  revision: #{service['revision']}"
          puts "  stateful: #{service['stateful'] == true ? 'yes' : 'no' }"
          puts "  scaling: #{service['container_count'] }"
          puts "  strategy: #{service['strategy']}"
          puts "  deploy_opts:"
          puts "    min_health: #{service['deploy_opts']['min_health']}"
          if service['deploy_opts']['wait_for_port']
            puts "    wait_for_port: #{service['deploy_opts']['wait_for_port']}"
          end
          if service['deploy_opts']['interval']
            puts "    interval: #{service['deploy_opts']['interval']}"
          end
          puts "  dns: #{service['name']}.#{grid}.kontena.local"

          if service['affinity'].to_a.size > 0
            puts "  affinity: "
            service['affinity'].to_a.each do |a|
              puts "    - #{a}"
            end
          end

          unless service['cmd'].to_s.empty?
            if service['cmd']
              puts "  cmd: #{service['cmd'].join(' ')}"
            else
              puts "  cmd: "
            end
          end

          if service['hooks'].to_a.size > 0
            puts "  hooks: "
            service['hooks'].to_a.each do |hook|
                puts "    - name: #{hook['name']}"
                puts "      type: #{hook['type']}"
                puts "      cmd: #{hook['cmd']}"
                puts "      oneshot: #{hook['oneshot']}"
            end
          end

          if service['secrets'].to_a.size > 0
            puts "  secrets: "
            service['secrets'].to_a.each do |s|
              puts "    - secret: #{s['secret']}"
              puts "      name: #{s['name']}"
              puts "      type: #{s['type']}"
            end
          end

          if service['env'].to_a.size > 0
            puts "  env: "
            service['env'].to_a.each do |e|
              puts "    - #{e}"
            end
          end

          unless service['net'].to_s.empty?
            puts "  net: #{service['net']}"
          end

          if service['ports'].to_a.size > 0
            puts "  ports:"
            service['ports'].to_a.each do |p|
              puts "    - #{p['node_port']}:#{p['container_port']}/#{p['protocol']}"
            end
          end

          if service['volumes'].to_a.size > 0
            puts "  volumes:"
            service['volumes'].to_a.each do |v|
              puts "    - #{v}"
            end
          end

          if service['volumes_from'].to_a.size > 0
            puts "  volumes_from:"
            service['volumes_from'].to_a.each do |v|
              puts "    - #{v}"
            end
          end

          if service['links'].to_a.size > 0
            puts "  links: "
            service['links'].to_a.each do |l|
              puts "    - #{l['alias']}"
            end
          end

          if service['cap_add'].to_a.size > 0
            puts "  cap_add:"
            service['cap_add'].to_a.each do |c|
              puts "    - #{c}"
            end
          end

          if service['cap_drop'].to_a.size > 0
            puts "  cap_drop:"
            service['cap_drop'].to_a.each do |c|
              puts "    - #{c}"
            end
          end

          unless service['log_driver'].to_s.empty?
            puts "  log_driver: #{service['log_driver']}"
            puts "  log_opts:"
            service['log_opts'].each do |opt, value|
              puts "    #{opt}: #{value}"
            end
          end

          unless service['memory'].to_s.empty?
            puts "  memory: #{int_to_filesize(service['memory'])}"
          end

          unless service['memory_swap'].to_s.empty?
            puts "  memory_swap: #{int_to_filesize(service['memory_swap'])}"
          end

          unless service['pid'].to_s.empty?
            puts "  pid: #{service['pid']}"
          end

          if service['health_check']
            puts "  health check:"
            puts "    protocol: #{service['health_check']['protocol']}"
            puts "    uri: #{service['health_check']['uri']}" if service['health_check']['protocol'] == 'http'
            puts "    port: #{service['health_check']['port']}"
            puts "    timeout: #{service['health_check']['timeout']}"
            puts "    interval: #{service['health_check']['interval']}"
            puts "    initial_delay: #{service['health_check']['initial_delay']}"
          end

          if service['health_status']
            puts "  health status:"
            puts "    healthy: #{service['health_status']['healthy']}"
            puts "    total: #{service['health_status']['total']}"
          end

          puts "  instances:"
          result = client(token).get("services/#{parse_service_id(service_id)}/containers")
          result['containers'].each do |container|
            puts "    #{container['name']}:"
            puts "      rev: #{container['deploy_rev']}"
            puts "      service_rev: #{container['service_rev']}"
            puts "      node: #{container['node']['name'] rescue 'unknown'}"
            puts "      dns: #{container['name']}.#{grid}.kontena.local"
            puts "      ip: #{container['overlay_cidr'].to_s.split('/')[0]}"
            puts "      public ip: #{container['node']['public_ip'] rescue 'unknown'}"
            if container['status'] == 'unknown'
              puts "      status: #{container['status'].colorize(:yellow)}"
            else
              puts "      status: #{container['status']}"
            end
            if container['state']['error'] && container['state']['error'] != ''
              puts "      reason: #{container['state']['error']}"
            end
            if container['state']['exit_code'] && container['state']['exit_code'] != ''
              puts "      exit code: #{container['state']['exit_code']}"
            end
          end
        end

        # @param [String] token
        # @param [String] service_id
        # @param [Hash] data
        def deploy_service(token, service_id, data)
          param = parse_service_id(service_id)
          client(token).post("services/#{param}/deploy", data)
        end

        # @param [String] token
        # @param [String] name
        # @return [Boolean]
        def wait_for_deploy_to_finish(token, name, timeout = 600)
          service = client(token).get("services/#{name}")
          desired_count = service['container_count']
          updated_at = DateTime.parse(service['updated_at']) rescue DateTime.now
          deployed = false
          Timeout::timeout(timeout) do
            until deployed
              containers = client(token).get("services/#{name}/containers")['containers']
              deployed = containers.size == desired_count && containers.all?{ |c|
                DateTime.parse(c['created_at']) >= updated_at rescue false
              }
              sleep 1
            end
          end

          deployed
        rescue Timeout::Error
          raise Kontena::Errors::StandardError.new(500, 'deploy timed out')
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
        def restart_service(token, service_id)
          param = parse_service_id(service_id)
          client(token).post("services/#{param}/restart", {})
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
            port, protocol = p.split('/')
            protocol ||= 'tcp'
            port_elements = port.split(':')
            container_port = port_elements[-1]
            node_port = port_elements[-2]
            ip = port_elements[-3] || '0.0.0.0'
            if node_port.nil? || container_port.nil?
              raise ArgumentError.new("Invalid port value #{p}")
            end
            {
              ip: ip,
              container_port: container_port,
              node_port: node_port,
              protocol: protocol
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
          case memory
          when /^\d+(k|K)$/
            memory.to_i * 1024
          when /^\d+(m|M)$/
            memory.to_i * 1024 * 1024
          when /^\d+(g|G)$/
            memory.to_i * 1024 * 1024 * 1024
          when /^\d+$/
            memory.to_i
          else
            raise ArgumentError.new("Invalid memory value: #{memory}")
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

        ##
        # @param [Array] log_opts
        # @return [Hash]
        def parse_log_opts(log_opts)
          opts = {}
          log_opts.each do |opt|
            key, value = opt.split('=')
            opts[key] = value
          end
          opts
        end

        # @param [Array<String>] secret_opts
        # @return [Array<Hash>]
        def parse_secrets(secret_opts)
          secrets = []
          secret_opts.each do |s|
            secret, name, type = s.split(':')
            secrets << {secret: secret, name: name, type: type}
          end
          secrets
        end

        # @param [String] time
        # @return [Integer, NilClass]
        def parse_relative_time(time)
          if time.end_with?('min')
            time.to_i * 60
          elsif time.end_with?('h')
            time.to_i * 60 * 60
          elsif time.end_with?('d')
            time.to_i * 60 * 60 * 24
          else
            time = time.to_i
            if time == 0
              nil
            else
              time
            end
          end
        end

        def int_to_filesize(int)
          {
            'B'  => 1000,
            'KB' => 1000 * 1000,
            'MB' => 1000 * 1000 * 1000,
            'GB' => 1000 * 1000 * 1000 * 1000,
            'TB' => 1000 * 1000 * 1000 * 1000 * 1000
          }.each_pair { |e, s| return "#{(int.to_i / (s / 1000))}#{e}" if int < s }
        end

        def parse_build_args(args)
          build_args = {}
          if args.kind_of?(Array)
            args.each do |arg|
              key, val = arg.split('=')
              build_args[key] = val
            end
          elsif args.kind_of?(Hash)
            build_args = build_args.merge(args)
            build_args.each do |k, v|
              if v.nil?
                build_args[k] = ENV[k.to_s] # follow docker compose functionality here
              end
            end
          end

          build_args
        end

        # @param [Symbol] health
        # @return [String]
        def health_status_icon(health)
          if health == :unhealthy
            icon = '⊗'.freeze
            icon.colorize(:red)
          elsif health == :partial
            icon = '⊙'.freeze
            icon.colorize(:yellow)
          elsif health == :healthy
            icon = '⊛'.freeze
            icon.colorize(:green)
          else
            icon = '⊝'.freeze
            icon.colorize(:clear)
          end
        end

        # @param [Hash] service
        # @return [Symbol]
        def health_status(service)
          if service['health_status']
            healthy = service.dig('health_status', 'healthy')
            total = service.dig('health_status', 'total')
            if healthy == 0
              :unhealthy
            elsif healthy > 0 && healthy < total
              :partial
            else
              :healthy
            end
          else
            :unknown
          end
        end
      end
    end
  end
end
