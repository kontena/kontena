require_relative 'common'

module Kontena::Cli::Grids
  class RemoveCustomPeerCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common

    parameter "PEER", "Custom peer ip address"

    def execute
      require_api_url
      token = require_token
      client(token).delete("grids/#{current_grid}/custom_peers/#{peer}")
    end
  end
end
