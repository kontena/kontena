require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Platform
  class Grids
    include Kontena::Cli::Common

    def list
      require_api_url

      grids['grids'].each do |grid|
        if grid['id'] == current_grid_id
          print color("* #{grid['name']} [#{grid['id']}]", :green, :bold)
        else
          puts "  #{grid['name']} [#{grid['id']}]"
        end
      end

      puts ''
      puts '# * - current grid'
    end

    def use(name)
      require_api_url

      grid = find_grid_by_name(name)
      if !grid.nil?
        self.current_grid = grid
        print color("Using #{grid['name']} [#{grid['id']}]", :green)
      else
        print color('Could not resolve grid by name. For a list of existing grids please run: kontena grids', :red)
      end

    end

    def show(name)
      require_api_url

      grid = find_grid_by_name(name)
      pp grid
    end

    def current
      require_api_url

      grid = client(token).get("grids/#{current_grid_id}")
      pp grid
    end

    def audit_log(options)
      require_api_url

      audit_logs = client(token).get("grids/#{current_grid_id}/audit_log", {limit: options.limit})
      headings = ['time', 'grid', 'resource type', 'resource name', 'event name', 'user', 'source ip', 'user agent']
      rows = []
      audit_logs['logs'].each do |log|

        rows << [ log['time'], log['grid'], log['resource_type'], log['resource_name'], log['event_name'], log['user_identity']['email'], log['source_ip'], log['user_agent']]
      end
      table = Terminal::Table.new :headings => headings, :rows => rows
      puts table
    end


    def create(name=nil)
      require_api_url

      token = require_token
      payload = {
        name: name
      }
      grid = client(token).post('grids', payload)
      puts "created #{grid['name']} (#{grid['id']})" if grid
    end

    def destroy(name)
      require_api_url

      grid = find_grid_by_name(name)

      if !grid.nil?
        response = client(token).delete("grids/#{grid['id']}")
        if response
          clear_current_grid if grid['id'] == current_grid_id
          puts "removed #{grid['name']} (#{grid['id']})"
        end
      else
        print color('Could not resolve grid by name. For a list of existing grids please run: kontena grids', :red)
      end
    end

    private

    def token
      @token ||= require_token
    end

    def grids
      @grids ||= client(token).get('grids')
    end

    def current_grid=(grid)
      inifile['platform']['grid'] = grid['id']
      inifile.save(filename: ini_filename)
    end

    def clear_current_grid
      inifile['platform'].delete('grid')
      inifile.save(filename: ini_filename)
    end

    def current_grid_id
      inifile['platform']['grid']
    end

    def find_grid_by_name(name)
      grids['grids'].find {|grid| grid['name'] == name }
    end
  end
end