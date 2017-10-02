class HostNodeSerializer < KontenaJsonSerializer

  attribute :id
  attribute :connected
  attribute :created_at
  attribute :updated_at
  attribute :last_seen_at
  attribute :name
  attribute :os
  attribute :engine_root_dir
  attribute :driver
  attribute :kernel_version
  attribute :labels
  attribute :mem_total
  attribute :mem_limit
  attribute :cpus
  attribute :public_ip
  attribute :private_ip
  attribute :agent_version
  attribute :docker_version
  attribute :peer_ips
  attribute :node_id
  attribute :node_number
  attribute :initial_member
  attribute :grid
  attribute :resource_usage

  def id
    object.to_path
  end

  def last_seen_at
    object.last_seen_at.try(:iso8601)
  end

  def engine_root_dir
    object.docker_root_dir
  end

  def peer_ips
    if object.grid
      object.grid.host_nodes.ne(id: object.id).map{|n|
        if n.region == object.region
          n.private_ip
        else
          n.public_ip
        end
      }.compact
    else
      []
    end
  end


  def initial_member
    object.grid && object.initial_member?
  end

  def grid
    grid = object.grid
    if grid
      {
        id: grid.to_path,
        name: grid.name,
        initial_size: grid.initial_size,
        stats: { statsd: grid.stats['statsd'] },
        trusted_subnets: grid.trusted_subnets
      }
    end
  end

  def resource_usage
    stats = object.host_node_stats.latest
    if stats
      {
        memory: stats.memory,
        load: stats.load,
        filesystem: stats.filesystem,
        usage: stats.usage,
        cpu: stats.cpu
      }
    end
  end
end
