require 'ipaddr'

class Container
  include Mongoid::Document
  include Mongoid::Timestamps

  field :container_id, type: String
  field :name, type: String
  field :driver, type: String
  field :exec_driver, type: String
  field :image, type: String
  field :image_version, type: String
  field :env, type: Array, default: []
  field :network_settings, type: Hash, default: {}
  field :state, type: Hash, default: {}
  field :finished_at, type: Time
  field :started_at, type: Time
  field :deleted_at, type: Time
  field :volumes, type: Array, default: []
  field :deploy_rev, type: String
  field :container_type, type: String, default: 'container'

  field :health_status, type: String
  field :health_status_at, type: Time

  validates_uniqueness_of :container_id, scope: [:host_node_id], allow_nil: true

  belongs_to :grid
  belongs_to :grid_service
  belongs_to :host_node
  has_many :container_logs
  has_many :container_stats
  has_one :overlay_cidr, dependent: :nullify

  index({ grid_id: 1 })
  index({ grid_service_id: 1 })
  index({ host_node_id: 1 })
  index({ updated_at: 1 })
  index({ deleted_at: 1 }, {sparse: true})
  index({ container_id: 1 })
  index({ state: 1 })
  index({ name: 1 })

  default_scope -> { where(deleted_at: nil, container_type: 'container') }
  scope :deleted, -> { where(deleted_at: {'$ne' => nil}) }
  scope :volumes, -> { where(deleted_at: nil, container_type: 'volume') }

  def to_path
    if self.grid_service
      "#{self.grid_service.to_path}/#{self.name}"
    else
      self.name
    end
  end

  ##
  # @return [String]
  def status
    return 'deleted' if self.deleted_at

    s = self.state
    if s['paused']
      'paused'
    elsif s['restarting']
      'restarting'
    elsif s['oom_killed']
      'oom_killed'
    elsif s['dead']
      'dead'
    elsif s['running']
      'running'
    else
      'stopped'
    end
  end

  def mark_for_delete
    self.set(:deleted_at => Time.now.utc)
    if self.overlay_cidr
      self.overlay_cidr.set(:container_id => nil, :reserved_at => nil)
    end
  end

  def running?
    self.status == 'running'
  end

  def stopped?
    self.status == 'stopped'
  end

  def paused?
    self.status == 'paused'
  end

  def ephemeral?
    self.volumes.nil? || self.volumes.size == 0
  end

  def deleted?
    self.status == 'deleted'
  end

  ##
  # @return [Boolean]
  def exists_on_node?
    return false if self.container_id.blank? || !self.host_node

    self.host_node.rpc_client.request('/containers/show', self.container_id.to_s)
    true
  rescue RpcClient::Error => e
    if e.code == 404
      false
    else
      raise e
    end
  end

  def up_to_date?
    self.image_version == self.grid_service.image.image_id && self.created_at > self.grid_service.updated_at
  end
end
