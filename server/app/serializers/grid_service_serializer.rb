class GridServiceSerializer < KontenaJsonSerializer

  attribute :id
  attribute :created_at
  attribute :created_at
  attribute :updated_at
  attribute :image
  attribute :affinity
  attribute :name
  attribute :stateful
  attribute :user
  attribute :instances
  attribute :cmd
  attribute :entrypoint
  attribute :net
  attribute :dns
  attribute :ports
  attribute :env
  attribute :secrets
  attribute :memory
  attribute :memory_swap
  attribute :cpu_shares
  attribute :volumes
  attribute :volumes_from
  attribute :cap_add
  attribute :cap_drop
  attribute :state
  attribute :grid
  attribute :stack
  attribute :links
  attribute :log_driver
  attribute :log_opts
  attribute :strategy
  attribute :deploy_opts
  attribute :pid
  attribute :instance_counts
  attribute :hooks
  attribute :revision
  attribute :stack_revision
  attribute :health_check
  attribute :health_status

  attr_reader :options

  def initialize(object, options = {})
    super(object)
    @options = options
  end

  def id
    object.to_path
  end

  def image
    object.image_name
  end

  def deploy_opts
    deploy_opts = object.deploy_opts
    {
      wait_for_port: deploy_opts.wait_for_port,
      min_healt: deploy_opts.min_health,
      interval: deploy_opts.interval
    }
  end

  def dns
    if object.default_stack?
      "#{object.name}.#{object.grid.name}.kontena.local"
    else
      "#{object.name}.#{object.stack.name}.#{object.grid.name}.kontena.local"
    end
  end

  def stateful
    object.stateful?
  end

  def instances
    object.container_count
  end

  def grid
    { id: object.grid.name }
  end

  def stack
    {
      id: object.stack.to_path,
      name: object.stack.name
    }
  end

  def secrets
    object.secrets.map do |s|
      { secret: s.secret, name: s.name, type: s.type }
    end
  end

  def links
    object.grid_service_links.map do |s|
      { id: s.linked_grid_service.to_path, alias: s.alias, name: s.linked_grid_service.name }
    end
  end

  def instance_counts
    if options[:counts]
      instance_counts = {
        total: options[:counts].dig(object.id, :total) || 0,
        running: options[:counts].dig(object.id, :running) || 0
      }
      {
        total: instance_counts[:total],
        running: instance_counts[:running]
      }
    else
      {
        total: object.containers.count,
        running: object.containers.where(:'state.running' => true).count
      }
    end
  end

  def hooks
    object.hooks.map do |h|
      { name: h.name, type: h.type, cmd: h.cmd, oneshot: h.oneshot }
    end
  end

  def health_check
    if object.health_check
    	{
    		protocol: object.health_check.protocol,
    		uri: object.health_check.uri,
    		port: object.health_check.port,
    		timeout: object.health_check.timeout,
    		initial_delay: object.health_check.initial_delay,
    		interval: object.health_check.interval
    	}
    end
  end

  def to_hash
   hash = super
   hash.delete(:health_check) unless object.health_check
   hash.delete(:health_status) unless object.health_check
   hash
 end
end
