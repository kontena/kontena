class GridService
  include Mongoid::Document
  include Mongoid::Timestamps

  LB_IMAGE = 'kontena/lb:latest'

  field :image_name, type: String
  field :labels, type: Hash, default: {}
  field :affinity, type: Array, default: []
  field :name, type: String
  field :stateful, type: Boolean, default: false
  field :user, type: String
  field :container_count, type: Fixnum, default: 1
  field :cmd, type: Array
  field :entrypoint, type: String
  field :ports, type: Array, default: []
  field :env, type: Array, default: []
  field :memory, type: Fixnum
  field :memory_swap, type: Fixnum
  field :cpu_shares, type: Fixnum
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

  field :deploy_requested_at, type: DateTime
  field :deployed_at, type: DateTime
  field :revision, type: Fixnum, default: 1
  field :strategy, type: String, default: 'ha'

  belongs_to :grid
  belongs_to :image
  belongs_to :stack
  has_many :containers
  has_many :container_logs
  has_many :container_stats
  has_many :audit_logs
  has_many :grid_service_deploys, dependent: :destroy
  embeds_many :grid_service_links
  embeds_many :hooks, class_name: 'GridServiceHook'
  embeds_many :secrets, class_name: 'GridServiceSecret'
  embeds_one :deploy_opts, class_name: 'GridServiceDeployOpt', autobuild: true
  embeds_one :health_check, class_name: 'GridServiceHealthCheck'

  index({ grid_id: 1 })
  index({ name: 1 })
  index({ grid_service_ids: 1 })

  validates_presence_of :name, :image_name
  validates_uniqueness_of :name, scope: [:grid_id]

  scope :load_balancer, -> { where(image_name: LB_IMAGE) }

  # @return [String]
  def to_path
    "#{self.grid.try(:name)}/#{self.name}"
  end

  # @param [String] state
  def set_state(state)
    self.set(:state => state)
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
  def deploying?
    self.state == 'deploying'
  end

  # @return [Boolean]
  def running?
    self.state == 'running'
  end

  def deploy_pending?
    self.grid_service_deploys.where(started_at: nil).count > 0
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
      @env_hash = self.env.inject({}){|h, n| h[n.split('=', 2)[0]] = n.split('=', 2)[1]; h }
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

  def linked_to_services
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
      if self.affinity.any?{|a| a.match(/^service(!=|==).+/)}
        return true
      end
      if self.affinity.any?{|a| a.match(/^container(!=|==).+/)}
        return true
      end
    end

    if self.volumes_from
      return true if self.volumes_from.size > 0
    end

    return true if self.net.to_s.match(/^container:.+/)

    false
  end

  def health_status
    healthy = 0

    self.containers.each do |c|
      healthy += 1 if c.health_status == 'healthy'
    end

    {healthy: healthy, total: self.containers.count}
  end
end
