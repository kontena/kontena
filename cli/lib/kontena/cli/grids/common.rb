module Kontena::Cli::Grids
  module Common

    ##
    # @param [Hash] grid
    def print_grid(grid)
      puts "#{grid['name']}:"
      puts "  uri: #{settings['server']['url'].sub('http', 'ws')}"
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
