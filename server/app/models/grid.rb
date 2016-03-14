require 'ipaddr'

class Grid
  include Mongoid::Document
  include Mongoid::Timestamps

  OVERLAY_BRIDGE_NETWORK_SIZE = 24

  def self.default_overlay_cidr
    @default_overlay_cidr ||= '10.81.0.0/19'
  end

  field :name, type: String
  field :token, type: String
  field :initial_size, type: Integer, default: 1
  field :overlay_cidr, type: String, default: -> { Grid.default_overlay_cidr }
  field :stats, type: Hash, default: {}

  has_many :host_nodes, dependent: :destroy
  has_many :host_node_stats
  has_many :grid_services, dependent: :destroy
  has_many :grid_secrets, dependent: :delete
  has_many :containers, dependent: :delete
  has_many :container_logs
  has_many :container_stats
  has_many :audit_logs
  has_many :registries, dependent: :delete
  has_many :overlay_cidrs, dependent: :delete
  has_and_belongs_to_many :users

  index({ name: 1 }, { unique: true })
  index({ token: 1 }, { unique: true })

  before_create :set_token

  # @return [String]
  def to_path
    self.name
  end

  def to_json(args = {})
    super(args.merge({:except => [:_id] }))
  end

  # @return [Array<Integer>]
  def free_node_numbers
    reserved_numbers = self.host_nodes.map{|node| node.node_number }.flatten
    (1..254).to_a - reserved_numbers
  end

  # @return [String]
  def overlay_network_size
    self.overlay_cidr.split('/')[1]
  end

  # @return [String]
  def overlay_network_ip
    self.overlay_cidr.split('/')[0]
  end

  # @return [Array<IPAddr>]
  def all_overlay_ips
    @all_overlay_ips ||= (IPAddr.new(self.overlay_cidr).to_range.map(&:to_s) - IPAddr.new("#{self.overlay_network_ip}/#{OVERLAY_BRIDGE_NETWORK_SIZE}").to_range.map(&:to_s))
  end

  # Does grid have all the initial nodes created?
  #
  # @return [Boolean]
  def has_initial_nodes?
    self.host_nodes.where(node_number: {:$lte => self.initial_size}).count == self.initial_size
  end

  # @param [HostNode] node
  # @return [Boolean]
  def initial_node?(node)
    node.node_number <= self.initial_size.to_i
  end

  def self.default_overlay_cidr=(cidr)
    @default_overlay_cidr = cidr
  end

  private

  def set_token
    self.token = SecureRandom.base64(64)
  end
end
