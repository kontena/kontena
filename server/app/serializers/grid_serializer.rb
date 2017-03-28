class GridSerializer < KontenaJsonSerializer

  attribute :id
  attribute :name
  attribute :initial_size
  attribute :stats
  attribute :default_affinity
  attribute :trusted_subnets
  attribute :node_count
  attribute :service_count
  attribute :container_count
  attribute :user_count

  def id
    object.to_path
  end

  def roles
    object.roles.map {|r| { name: r.name, description: r.description }}
  end

  def stats
    object.stats['statsd']
  end

  def default_affinity
    object.default_affinity.to_a
  end

  def node_count
    object.host_nodes.count
  end

  def service_count
    object.grid_services.count
  end

  def container_count
    object.containers.count
  end

  def user_count
    object.users.count
  end
end
