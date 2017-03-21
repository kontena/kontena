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

    def id
      object.node_id
    end

    def created_at
      object.created_at.to_s
    end

    def updated_at
      object.updated_at.to_s
    end

    def peer_ips
      object.grid.host_nodes.ne(id: object.id).map{|n|
        if n.region == object.region
          n.private_ip
        else
          n.public_ip
        end
      }.compact
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
  end
end
