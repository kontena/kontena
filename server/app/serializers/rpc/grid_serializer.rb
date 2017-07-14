require_relative '../rpc_serializer'

module Rpc
  class GridSerializer < RpcSerializer
    attribute :id
    attribute :name
    attribute :initial_size
    attribute :trusted_subnets
    attribute :subnet
    attribute :supernet
    attribute :stats
    attribute :logs
    attribute :weave

    def id
      object.to_path
    end

    def stats
      {
        statsd: object.stats['statsd'],
      }
    end

    def logs
      if object.grid_logs_opts
        {
          forwarder: object.grid_logs_opts.forwarder,
          opts: object.grid_logs_opts.opts,
        }
      end
    end

    def weave
      {
        secret: object.weave_secret,
      }
    end
  end
end
