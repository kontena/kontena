class GridService
  include Mongoid::Document
  include Mongoid::Timestamps

  field :image_name, type: String
  field :labels, type: Array, default: []
  field :affinity, type: Array, default: []
  field :name, type: String
  field :stateful, type: Boolean
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
  field :state, type: String, default: 'initialized'

  belongs_to :grid
  belongs_to :image
  has_many :containers
  has_many :container_logs
  has_many :container_stats
  has_many :audit_logs
  embeds_many :grid_service_links

  index({ grid_id: 1 })
  index({ name: 1 })
  index({ grid_service_ids: 1 })

  validates_presence_of :name, :image_name
  validates_uniqueness_of :name, scope: [:grid_id]

  scope :visible, -> { where(name: {'$nin' => ['vpn', 'registry']}) }

  def to_path
    "#{self.grid.try(:name)}/#{self.name}"
  end

  def set_state(state)
    self.update_attribute(:state, state)
  end

  def stateful?
    self.stateful == true
  end

  def stateless?
    !stateful?
  end

  def deploying?
    self.state == 'deploying'
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
end
