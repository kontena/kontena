require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Grids
  class Grids
    include Kontena::Cli::Common

    def list
      require_api_url

      if grids['grids'].size == 0
        print color("You don't have any grids yet. Create first one with 'kontena grids create' command", :yellow)
      end

      puts '%-30.30s %-8s %-12s %-10s' % ['Name', 'Nodes', 'Services', 'Users']
      grids['grids'].each do |grid|
        if grid['id'] == current_grid
          name = "#{grid['name']} *"
        else
          name = grid['name']
        end
        puts '%-30.30s %-8s %-12s %-10s' % [name, grid['node_count'], grid['service_count'], grid['user_count']]
      end
    end

    def use(name)
      require_api_url

      grid = find_grid_by_name(name)
      if !grid.nil?
        self.current_grid = grid
        puts "Using grid: #{grid['name'].cyan}"
      else
        print color('Could not resolve grid by name. For a list of existing grids please run: kontena grid list', :red)
      end

    end

    def show(name)
      require_api_url

      grid = find_grid_by_name(name)
      print_grid(grid)
    end

    def current
      require_api_url
      if current_grid.nil?
        puts 'No grid selected. To select grid, please run: kontena grid use <grid name>'
      else
        grid = client(require_token).get("grids/#{current_grid}")
        print_grid(grid)
      end
    end

    def create(name = nil, opts)
      require_api_url

      token = require_token
      payload = {
        name: name
      }
      payload[:initial_size] = opts.initial_size if opts.initial_size
      grid = client(token).post('grids', payload)
      if grid
        self.current_grid = grid
        puts "Using grid: #{grid['name'].cyan}"
      end
    end

    def destroy(name)
      require_api_url
      token = require_token
      grid = find_grid_by_name(name)

      if !grid.nil?
        response = client(token).delete("grids/#{grid['id']}")
        if response
          clear_current_grid if grid['id'] == current_grid
          puts "removed #{grid['name'].cyan}"
        end
      else
        print color('Could not resolve grid by name. For a list of existing grids please run: kontena grid list', :red)
      end
    end

    private

    ##
    # @param [Hash] grid
    def print_grid(grid)
      puts "#{grid['name']}:"
      puts "  token: #{grid['token']}"
      puts "  users: #{grid['user_count']}"
      puts "  nodes: #{grid['node_count']}"
      puts "  services: #{grid['service_count']}"
      puts "  containers: #{grid['container_count']}"
    end

    def grids
      @grids ||= client(require_token).get('grids')
    end

    def find_grid_by_name(name)
      grids['grids'].find {|grid| grid['name'] == name }
    end
  end
end
