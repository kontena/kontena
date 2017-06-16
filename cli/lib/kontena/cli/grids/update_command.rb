require_relative 'common'

module Kontena::Cli::Grids
  class UpdateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    parameter "NAME", "Grid name"

    include Common::Parameters

    requires_current_master_token

    def execute
      validate_grid_parameters

      payload = {}

      build_grid_parameters(payload)

      client.put("grids/#{name}", payload)
    end
  end
end
