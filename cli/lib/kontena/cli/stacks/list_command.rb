require_relative 'common'

module Kontena::Cli::Stacks
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Lists all installed stacks on a grid in Kontena Master"

    requires_current_master
    requires_current_master_token

    def execute
      list_stacks
    end

    def list_stacks
      response = client.get("grids/#{current_grid}/stacks")

      titles = ['NAME', 'STACK', 'SERVICES', 'STATE', 'EXPOSED PORTS']
      puts "%-30s %-40s %-10s %-10s %-50s" % titles

      response['stacks'].each do |stack|
        ports = stack_ports(stack)
        health = stack_health(stack)
        case health
        when :unhealthy
          icon = glyph(:circled_x)
          color = :red
        when :partial
          icon = glyph(:circled_dot)
          color = :yellow
        when :healthy
          icon = glyph(:circled_star)
          color = :green
        else
          icon = glyph(:circled_dash)
          color = :dim
        end

        vars = [
          pastel.send(color, icon),
          "#{stack['name']}",
          "#{stack['stack']}:#{stack['version']}",
          stack['services'].size,
          stack['state'],
          ports.join(",")
        ]

        puts "%s %-28s %-40s %-10s %-10s %-50s" % vars
      end
    end

    # @param [Hash] stack
    # @return [Array<String>]
    def stack_ports(stack)
      ports = []
      stack['services'].each{|s|
        service_ports = s['ports'].map{|p|
          p['ip'] = '*' if p['ip'] == '0.0.0.0'
          "#{p['ip']}:#{p['node_port']}->#{p['container_port']}/#{p['protocol']}"
        }
        ports = ports + service_ports unless service_ports.empty?
      }
      ports
    end

    # @param [Hash] stack
    # @return [Symbol]
    def stack_health(stack)
      services_count = stack['services'].size
      return :unknown if services_count == 0

      fully_healthy_count = 0
      partial_healthy_count = 0
      unhealthy_count = 0
      unknown_count = 0
      stack['services'].each { |s|
        total = s.dig('health_status', 'total').to_i
        healthy = s.dig('health_status', 'healthy').to_i
        if total > 0 && healthy == total
          fully_healthy_count += 1
        elsif healthy < total && healthy > 0
          partial_healthy_count += 1
        elsif healthy == 0 && total > 0
          unhealthy_count += 1
        else
          unknown_count += 1
        end
      }
      return :partial if partial_healthy_count > 0
      return :partial if unhealthy_count > 0 && fully_healthy_count > 0
      return :unhealthy if unhealthy_count == services_count
      return :healthy if fully_healthy_count == services_count
      return :healthy if fully_healthy_count > 0 && unknown_count > 0

      :unknown
    end
  end
end
