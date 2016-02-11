require_relative 'common'

module Kontena::Cli::Grids
  class AddCustomPeerCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "PEER", "Custom peer ip address"

    def execute
      require_api_url
      token = require_token
      data = { peer: peer }
      client(token).post("grids/#{current_grid}/custom_peers", data)
    end
  end
end
