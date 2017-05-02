require_relative 'common'

module Kontena::Cli::Grids
  class UpdateCommand < Kontena::Command
    include Common

    parameter "NAME", "Grid name"

    include Common::Parameters

    option "--no-default-affinity", :flag, "Unset grid default affinity"
    option "--no-statsd-server", :flag, "Unset statsd server setting"

    requires_current_master_token

    def execute
      validate_grid_parameters

      payload = {}

      build_grid_parameters(payload)

      if no_statsd_server?
        payload[:stats] = { statsd:  nil }
      end

      if no_default_affinity?
        payload[:default_affinity] = []
      end

      client.put("grids/#{name}", payload)
    end
  end
end
