require_relative 'common'

module Kontena::Cli::Grids
  class EnvCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common

    option ["-e", "--export"], :flag, "Add export", default: false

    def execute
      require_api_url
      if current_grid.nil?
        abort 'No grid selected. To select grid, please run: kontena grid use <grid name>'
      else
        grid = client(require_token).get("grids/#{current_grid}")
        prefix = export? ? 'export ' : ''
        puts "#{prefix}KONTENA_URI=#{settings['server']['url'].sub('http', 'ws')}"
        puts "#{prefix}KONTENA_TOKEN=#{grid['token']}"
      end
    end
  end
end
