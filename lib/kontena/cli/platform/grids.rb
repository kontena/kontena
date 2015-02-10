require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Platform
  class Grids
    include Kontena::Cli::Common

    def list
      require_api_url

      token = require_token

      grids = client(token).get('grids')
      grids['grids'].each do |grid|
        if grid['id'] == current_grid
          print color("* #{grid['name']} [#{grid['id']}]", :green, :bold)
        else
          puts "  #{grid['name']} [#{grid['id']}]"
        end
      end

      puts ''
      puts '# * - current grid'
    end

    def switch_to_grid(name)
      require_api_url
      token = require_token

      grids = client(token).get('grids')
      grids['grids'].each do |grid|
        if grid['name'] == name
          inifile['platform']['grid'] = grid['id']
          inifile.save(filename: ini_filename)
          print color("Using #{grid['name']} [#{grid['id']}]", :green)
          return true
        end
      end
      print color('Could not resolve grid by name. For a list of existing grids please run: kontena grids', :red)
    end

    def create(name=nil)
      require_api_url

      token = require_token
      payload = {
        name: name
      }
      grid = client(token).post('grids', payload)
      puts "created #{grid['name']} (#{grid['id']})"
    end

    private
    def current_grid
      inifile['platform']['grid']
    end
  end
end