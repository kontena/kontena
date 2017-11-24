require_relative 'common'

module Kontena::Cli::Stacks
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::TableGenerator::Helper
    include Common

    banner "Lists all installed stacks on a grid in Kontena Master"

    requires_current_master
    requires_current_master_token

    HEALTH_ICONS = {
      unhealthy: Kontena.pastel.red('⊗').freeze,
      partial:   Kontena.pastel.yellow('⊙').freeze,
      healthy:   Kontena.pastel.green('⊛').freeze,
      default:   Kontena.pastel.dim('⊝').freeze
    }

    def stacks_by_names(stacks, name_list)
      name_list.map { |name| stacks.find { |stack| stack['name'] == name } }.compact
    end

    def build_depths(stacks)
      stacks.sort_by { |s| s['name'] }.each do |stack|
        stack['depth'] += 1
        stacks_by_names(stacks, stack['children'].map { |n| n['name'] }).each do |child_stack|
          child_stack['depth'] += stack['depth']
        end
      end
      stacks
    end

    def get_stacks
      client.get("grids/#{current_grid}/stacks")['stacks'].tap { |stacks| stacks.map { |stack| stack['depth'] = 0 } }
    end

    def fields
      return ['name'] if quiet?
      {
        name: 'name',
        stack: 'stack',
        services: 'services_count',
        state: 'state',
        'exposed ports' => 'ports'
      }
    end

    def execute
    stacks = build_depths(get_stacks)

    print_table(stacks) do |row|
        next if quiet?
        row['name'] = health_icon(stack_health(row)) + " " + tree_icon(row) + row['name']
        row['stack'] = "#{row['stack']}:#{row['version']}"
        row['services_count'] = row['services'].size
        row['ports'] = stack_ports(row).join(',')
        row['state'] = pastel.send(state_color(row['state']), row['state'])
      end
    end

    def state_color(state)
      case state
      when 'running' then :green
      when 'deploying', 'initialized' then :blue
      when 'stopped' then :red
      when 'partially_running' then :yellow
      else :clear
      end
    end

    def health_icon(health)
      HEALTH_ICONS.fetch(health) { HEALTH_ICONS[:default] }
    end

    def tree_icon(row)
      return '' unless $stdout.tty?
      parent = row['parent']
      children = row['children'] || []
      if parent.nil? && children.empty?
        # solo
        char = ''
      elsif parent.nil? && !children.empty?
        char = ''
      elsif !parent.nil?
        char = '┗━'
      end
      left_pad = ' ' * (2 * (row['depth'] - 1))
      right_pad = row['depth'] > 1 ? '━' : ''
      left_pad + char + right_pad
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
