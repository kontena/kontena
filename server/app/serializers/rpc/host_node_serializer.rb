require_relative '../rpc_serializer'

module Rpc
  class HostNodeSerializer < RpcSerializer
    attribute :id
    attribute :created_at
    attribute :updated_at
    attribute :name
    attribute :labels
    attribute :overlay_ip
    attribute :peer_ips
    attribute :node_number
    attribute :initial_member
    attribute :grid
    attribute :plugins

    def id
      object.node_id
    end

    def created_at
      object.created_at.to_s
    end

    def updated_at
      object.updated_at.to_s
    end

    def initial_member
      object.initial_member?
    end

    def grid
      if grid = object.grid
        GridSerializer.new(grid).to_hash
      else
        {}
      end
    end

    def plugins
      object.grid.docker_plugins.reject { |p| p.label && object.labels && !object.labels.include?(p.label)}.map { |p|
        {
          name: p.name,
          alias: p.alias,
          config: p.config
        }
      }
    end
  end
end
