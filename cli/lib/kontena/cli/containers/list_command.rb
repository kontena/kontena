module Kontena::Cli::Containers
  class ListCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::GridOptions
    include Kontena::Cli::TableGenerator::Helper

    option ['-a', '--all'], :flag, 'Show all containers'

    requires_current_master
    requires_current_master_token

    NON_STOP_STATES = ['paused', 'restarting', 'oom_killed', 'dead', 'running']

    def fields
      return ['id'] if quiet?
      { container_id: 'id', image: 'image', command: 'cmd', created: 'created_at', status: 'state' }
    end

    def execute
      result = spin_if(!quiet?, "Retrieving container list") do
        Array(client.get("containers/#{current_grid}#{'?all=1' if all?}")['containers'])
      end

      print_table(result.reverse) do |row|
        row['id'] = container_id(row)
        row['created_at'] = time_ago(row['created_at'])
        row['cmd'] = truncate_cmd(row)
        row['state'] = container_state(row)
      end
    end

    def container_id(row)
      "#{row['node']['name']}/#{row['name']}"
    end

    def truncate_cmd(row)
      cmd = row['cmd'].nil? ? '' : row['cmd'].join(' ')
      cmd = "#{cmd[0..24]}#{pastel.cyan('..')}" if cmd.length > 26
      "\"#{cmd}\""
    end

    def container_state(row)
      NON_STOP_STATES.find { |state| row.fetch('state', {})[state] == true } || pastel.cyan('stopped')
    end
  end
end
