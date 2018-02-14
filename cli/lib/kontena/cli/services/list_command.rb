require_relative 'services_helper'

module Kontena::Cli::Services
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::TableGenerator::Helper
    include ServicesHelper

    option '--stack', 'STACK', 'Stack name'

    requires_current_master
    requires_current_master_token

    def services
      client.get("grids/#{current_grid}/services#{"?stack=#{stack}" if stack}")['services'].sort_by{|s| s['updated_at'] }.reverse
    end

    def fields
      quiet? ? ['name'] : {name: 'name', instances: 'instances', stateful: 'stateful', state: 'state', "exposed ports" => 'ports' }
    end

    def service_port(port)
      "#{port['ip']}:#{port['node_port']}->#{port['container_port']}/#{port['protocol']}"
    end

    def stack_id(service)
      if quiet?
        service.fetch('stack', {}).fetch('id', 'null')
      else
        service.fetch('stack', {}).fetch('name', nil)
      end
    end

    def service_name(service)
      stack_id = stack_id(service)
      return service['name'] if stack_id == 'null'
      [ stack_id(service), service['name'] ].compact.join('/')
    end

    def state_color(state)
      case state
      when 'running' then :green
      when 'initialized' then :cyan
      when 'stopped' then :red
      when 'terminated' then :dim
      else :blue
      end
    end

    def execute
      print_table(services) do |row|
        row['name'] = quiet? ? service_name(row) :  health_status_icon(health_status(row)) + " " + service_name(row)
        next if quiet?
        row['stateful'] = row['stateful'] ? pastel.green('yes') : 'no'
        row['ports'] = row['ports'].map(&method(:service_port)).join(',')
        row['state'] = pastel.send(state_color(row['state']), row['state'])

        instances = [row['instance_counts']['running'], row['instances']]
        if instances.first < instances.last
          instances[0] = pastel.cyan(instances[0].to_s)
        end
        row['instances'] = instances.join(' / ')
      end
    end
  end
end
