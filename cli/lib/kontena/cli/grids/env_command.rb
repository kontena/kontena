require_relative 'common'

module Kontena::Cli::Grids
  class EnvCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    parameter "[NAME]", "Grid name"
    option ["-e", "--export"], :flag, "Add export", default: false

    def execute
      require_api_url

      name_or_current = name.nil? ? current_grid : name

      if name_or_current.nil?
        exit_with_error "No grid selected. Use: kontena grid env <name>, or select a grid with: kontena grid use <name>"
      else
        token = get_grid_token(name_or_current)
        exit_with_error("Grid not found") unless token

        grid_uri = self.current_master['url'].sub('http', 'ws')


        prefix = export? ? 'export ' : ''

        puts "#{prefix}KONTENA_URI=#{grid_uri}"
        puts "#{prefix}KONTENA_TOKEN=#{token['token']}"
      end
    end
  end
end
