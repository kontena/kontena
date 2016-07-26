require_relative 'common'

module Kontena::Cli::Stacks
  class ShowCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "NAME", "Service name"

    def execute
      require_api_url
      token = require_token

      show_stack(token, name)
    end

    def show_stack(token, name)
      stack = client(token).get("stacks/#{current_grid}/#{name}")

      puts "#{stack['id']}:"
      puts "  state: #{stack['state']}"
      puts "  created_at: #{stack['created_at']}"
      puts "  updated_at: #{stack['updated_at']}"
      puts "  version: #{stack['version']}"
      puts "  services:"
      stack['grid_services'].each do |service|
        puts "    #{service['id']}:"
        puts "      status: #{service['state'] }"
        puts "      image: #{service['image']}"
        puts "      revision: #{service['revision']}"
        puts "      stateful: #{service['stateful'] == true ? 'yes' : 'no' }"
        puts "      scaling: #{service['container_count'] }"
        puts "      strategy: #{service['strategy']}"
      end
    end
  end
end
