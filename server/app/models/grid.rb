require 'ipaddr'

class Grid
  include Mongoid::Document
  include Mongoid::Timestamps

  OVERLAY_BRIDGE_NETWORK_SIZE = 24

  field :name, type: String
  field :token, type: String
  field :discovery_url, type: String
  field :initial_size, type: Integer
  field :overlay_cidr, type: String, default: '10.81.0.0/19'

  has_many :host_nodes
  has_many :grid_services
  has_many :containers
  has_many :container_logs
  has_many :container_stats
  has_many :audit_logs
  has_many :registries, dependent: :delete
  has_and_belongs_to_many :users

  index({ name: 1 }, { unique: true })
  index({ token: 1 }, { unique: true })

  before_create :set_token

  def to_path
    self.name
  end

  def to_json(args = {})
    super(args.merge({:except => [:_id] }))
  end

  ##
  # @return [Array<Integer>]
  def free_node_numbers
    reserved_numbers = self.host_nodes.map{|node| node.node_number }.flatten
    (1..254).to_a - reserved_numbers
  end

  def overlay_network_size
    self.overlay_cidr.split('/')[1]
  end

  def overlay_network_ip
    self.overlay_cidr.split('/')[0]
  end

  def all_overlay_ips
    @all_overlay_ips ||= (IPAddr.new(self.overlay_cidr).to_range.map(&:to_s) - IPAddr.new("#{self.overlay_network_ip}/#{OVERLAY_BRIDGE_NETWORK_SIZE}").to_range.map(&:to_s))
  end

  def reserved_overlay_ips
    reserved_ips = self.containers.map{|c| c.overlay_cidr.to_s.split('/')[0] }
  end

  def available_overlay_ips
    self.all_overlay_ips - self.reserved_overlay_ips
  end

  private

  def set_token
    self.token = SecureRandom.base64(64)
  end
end
