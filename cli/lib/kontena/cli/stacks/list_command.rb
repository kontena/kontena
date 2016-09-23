require_relative 'common'

module Kontena::Cli::Stacks
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    COLUMNS = "%-30s %-10s %-10s".freeze

    def execute
      require_api_url
      require_token

      list_stacks
    end

    private

    def list_stacks
      response = client(token).get("stacks/#{current_grid}")
      
      titles = ['NAME', 'SERVICES', 'STATE']
      puts COLUMNS % titles

      response['stacks'].each do |stack|
        vars = [
          stack['name'],
          stack['grid_services'].size,
          stack['state']
        ]

        puts COLUMNS % vars
      end
    end

  end
end
