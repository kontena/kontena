require 'kontena/client'
require_relative '../common'
module Kontena::Cli::Platform
  class Nodes
    include Kontena::Cli::Common

    def list
      require_api_url
      token = require_token

      grids = client(token).get("grids/#{current_grid}/nodes")
      grids['nodes'].each do |node|
        if node['connected']
          print_color = :green
        else
          print_color = :red
        end
        print color "#{node['name']} #{node['os']} #{node['driver']}", print_color
      end
    end

    private
    def current_grid
      inifile['platform']['grid']
    end
  end
end
