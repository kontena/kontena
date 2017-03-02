require_relative 'common'

module Kontena::Cli::Grids
  class UpdateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    parameter "NAME", "Grid name"
    option "--statsd-server", "STATSD_SERVER", "Statsd server address (host:port)"
    option "--default-affinity", "[AFFINITY]", "Default affinity rule for the grid", multivalued: true
    option "--log-driver", "LOG_DRIVER", "Set grid wide log driver"
    option "--log-opt", "[LOG_OPT]", "Set log options (key=value)", multivalued: true

    def execute
      require_api_url
      token = require_token
      validate_log_opts
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

      if log_driver
        payload[:logs] = {
          driver: log_driver,
          opts: parse_log_opts
        }
      end

      if default_affinity_list
        payload[:default_affinity] = default_affinity_list
      end
      client(token).put("grids/#{name}", payload)
    end

    def validate_log_opts
      if !log_opt_list.empty? && log_driver.nil?
        raise Kontena::Errors::StandardError.new(1, "Need to specify --log-driver when using --log-opt")
      end
    end

    def parse_log_opts
      opts = {}
      log_opt_list.each do |opt|
        key, value = opt.split('=')
        opts[key.to_sym] = value
      end
      opts
    end
  end
end
