require_relative 'event_stream'
class GridService
  include Mongoid::Document
  include Mongoid::Timestamps
  include EventStream

  LB_IMAGE = 'kontena/lb'

  field :image_name, type: String
  field :labels, type: Hash, default: {}
  field :affinity, type: Array, default: []
  field :name, type: String
  field :stateful, type: Boolean, default: false
  field :user, type: String
  field :container_count, type: Integer, default: 1
  field :cmd, type: Array
  field :entrypoint, type: String
  field :ports, type: Array, default: []
  field :env, type: Array, default: []
  field :memory, type: Integer
  field :memory_swap, type: Integer
  field :shm_size, type: Integer
  field :cpus, type: Float
  field :cpu_shares, type: Integer
  field :volumes, type: Array, default: []
  field :volumes_from, type: Array, default: []
  field :privileged, type: Boolean
  field :cap_add, type: Array, default: []
  field :cap_drop, type: Array, default: []
  field :net, type: String, default: 'bridge'
  field :state, type: String, default: 'initialized'
  field :log_driver, type: String
  field :log_opts, type: Hash, default: {}
  field :devices, type: Array, default: []
  field :pid, type: String
  field :read_only, type: Boolean, default: false

  field :deploy_requested_at, type: DateTime
  field :deployed_at, type: DateTime
  field :revision, type: Integer, default: 1
  field :stack_revision, type: Integer
  field :strategy, type: String, default: 'ha'
  field :stop_grace_period, type: Fixnum, default: 10

  belongs_to :grid
  belongs_to :image
  belongs_to :stack
  has_many :grid_service_instances, dependent: :destroy
  has_many :containers
  has_many :container_logs
  has_many :container_stats
  has_many :audit_logs
  has_many :grid_service_deploys, dependent: :destroy
  has_many :event_logs
  has_many :grid_domain_authorizations
  has_and_belongs_to_many :networks
  embeds_many :grid_service_links
  embeds_many :hooks, class_name: 'GridServiceHook'
  embeds_many :secrets, class_name: 'GridServiceSecret'
  embeds_many :service_volumes, class_name: 'ServiceVolume'
  embeds_many :certificates, class_name: 'GridServiceCertificate'
  embeds_one :deploy_opts, class_name: 'GridServiceDeployOpt', autobuild: true
  embeds_one :health_check, class_name: 'GridServiceHealthCheck'

  index({ grid_id: 1 })
  index({ name: 1 })
  index({ grid_service_ids: 1 })

  validates_presence_of :name, :image_name, :grid_id, :stack_id
  validates_uniqueness_of :name, scope: [:grid_id, :stack_id]

  scope :load_balancer, -> { where(image_name: /^#{LB_IMAGE}:.+/) }

  before_validation :ensure_stack

  # @return [String]
  def to_path
    "#{self.grid.try(:name)}/#{self.stack.try(:name)}/#{self.name}"
  end

  # @return [String]
  def name_with_stack
    if default_stack?
      self.name
    else
      "#{self.stack.name}.#{self.name}"
    end
  end

  # @return [String]
  def qualified_name
    parts = []
    parts << self.stack.name unless self.default_stack?
    parts << self.name

    parts.join('/')
  end

  # @return [Boolean]
  def default_stack?
    self.stack.try(:name).to_s == Stack::NULL_STACK
  end

  # @param [Integer] instance_number
  # @return [String]
  def instance_hostname(instance_number)
    "#{self.name}-#{instance_number}"
  end

  # @return [String]
  def domain
    self.stack.domain
  end

  # @param [String] state
  def set_state(state)
    state_changed = self.state != state
    self.set(:state => state)
    publish_update_event if state_changed
  end

  # @return [Boolean]
  def stateful?
    self.stateful == true
  end

  # @return [Boolean]
  def stateless?
    !stateful?
  end

  def daemon?
    self.strategy == 'daemon'
  end

  # @return [Boolean]
  def initialized?
    self.state == 'initialized'
  end

  # @return [Boolean]
  def running?
    self.state == 'running'
  end

  # @return [Boolean]
  def stopped?
    self.state == 'stopped'
  end

  # @return [Boolean]
  def stack_exposed?
    return false unless self.stack
    self.stack.exposed_service?(self)
  end

  # The service has deploys created, queued or started, but not yet finished.
  #
  # Equvialent to deploy_pending? || deploy_running?
  #
  # Ignores any expired deploys.
  #
  # @return [Boolean]
  def deploying?
    self.grid_service_deploys.deploying.count > 0
  end

  # The service has deploys created or queued, but not yet started, running or finished.
  #
  # @return [Boolean]
  def deploy_pending?
    self.grid_service_deploys.pending.count > 0
  end

  # The service has deploys that have been started, but not yet finished or timeout.
  #
  # @return [Boolean]
  def deploy_running?
    self.grid_service_deploys.running.count > 0
  end

  # @return [Boolean]
  def load_balancer?
    self.image_name.to_s.include?(LB_IMAGE) ||
      (self.env && self.env.include?('KONTENA_SERVICE_ROLE=lb'))
  end

  # @return [Boolean]
  def linked_to_load_balancer?
    self.grid_service_links.map{|l| l.linked_grid_service }.any?{|s| s.load_balancer? }
  end

  # @return [Array<GridService>]
  def linked_to_load_balancers
    self.grid_service_links.map{|l| l.linked_grid_service }.select{|s| s.load_balancer? }
  end

  # @param [GridService] service
  # @param [String] service_alias
  def link_to(service, service_alias = nil)
    service_alias = service.name if service_alias.nil?
    self.grid_service_links << GridServiceLink.new(
      linked_grid_service: service,
      alias: service_alias
    )
  end

  # @return [Hash]
  def env_hash
    if @env_hash.nil?
      @env_hash = Hash[Array(self.env).map { |kv_pair| kv_pair.split('=', 2) }]
    end

    @env_hash
  end

  # @return [Boolean]
  def overlay_network?
    self.net.to_s == 'bridge'
  end

  ##
  # @return [Container,NilClass]
  def container_by_name(name)
    self.containers.find_by(name: name.to_s)
  end

  ##
  # @return [Container,NilClass]
  def volume_by_name(name)
    self.containers.unscoped.volumes.find_by(name: name.to_s)
  end

  # @return [Mongoid::Criteria]
  def linked_from_services
    self.grid.grid_services.where(:'grid_service_links.linked_grid_service_id' => self.id)
  end

  # Resolve services that depend on us
  #
  # @return [Array<GridService>]
  def dependant_services
    grid = self.grid
    dependant = []
    dependant += grid.grid_services.where(:$or => [
        {:volumes_from => {:$regex => /^#{self.name}-%s/}},
        {:volumes_from => {:$regex => /^#{self.name}-\d+/}},
        {:affinity => "service==#{self.name}"},
        {:affinity => "service!=#{self.name}"},
        {:net => {:$regex => /^container:#{self.name}-%s/}},
        {:net => {:$regex => /^container:#{self.name}-\d+/}}
      ]
    )
    dependant.delete(self)

    dependant
  end

  # Are there any dependant services?
  #
  # @return [Boolean]
  def dependant_services?
    self.dependant_services.size > 0
  end

  # Is service depending on other services?
  #
  # @return [Boolean]
  def depending_on_other_services?
    if self.affinity
      if self.affinity.any?{|a| a.match(/\Aservice(!=|==).+/)}
        return true
      end
      if self.affinity.any?{|a| a.match(/\Acontainer(!=|==).+/)}
        return true
      end
    end

    if self.volumes_from
      return true if self.volumes_from.size > 0
    end

    return true if self.net.to_s.match(/\Acontainer:.+/)

    false
  end

  def health_status
    healthy = 0
    unhealthy = 0
    self.containers.each do |c|
      healthy += 1 if c.health_status == 'healthy'
      unhealthy += 1 if c.health_status == 'unhealthy'
    end

    {healthy: healthy, unhealthy: unhealthy, total: self.containers.count}
  end

  def ensure_stack
    if self.grid_id && self.stack_id.nil?
      self.stack = self.grid.stacks.find_by(name: Stack::NULL_STACK)
    end
  end

  # @return [Array<String>]
  def affinity
    affinity = super
    if (affinity.nil? || affinity.empty?) && self.grid
      self.grid.default_affinity.to_a
    else
      affinity.to_a
    end
  end
end
