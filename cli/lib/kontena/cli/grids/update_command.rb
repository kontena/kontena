require_relative 'common'

module Kontena::Cli::Grids
  class UpdateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    parameter "NAME", "Grid name"
    option "--statsd-server", "STATSD_SERVER", "Statsd server address (host:port)"
    option "--default-affinity", "[AFFINITY]", "Default affinity rule for the grid", multivalued: true

    def execute
      require_api_url
      token = require_token
      payload = {}
      if statsd_server
        server, port = statsd_server.split(':')
        payload[:stats] = {
          statsd: {
            server: server,
            port: port || 8125
          }
        }
      end
      if default_affinity_list
        payload[:default_affinity] = default_affinity_list
      end
      client(token).put("grids/#{name}", payload)
    end
  end
end
