require 'ipaddr'
require_relative 'event_stream'

class Grid
  include Mongoid::Document
  include Mongoid::Timestamps
  include Authority::Abilities
  include EventStream
  include Logging

  NODE_NUMBERS = (1..254)
  SUBNET = '10.81.0.0/16'
  SUPERNET = '10.80.0.0/12'

  field :name, type: String
  field :token, type: String
  field :initial_size, type: Integer, default: 1
  field :trusted_subnets, type: Array, default: []
  field :stats, type: Hash, default: {}
  field :default_affinity, type: Array, default: []
  field :subnet, type: String, default: SUBNET
  field :supernet, type: String, default: SUPERNET

  has_many :host_nodes, dependent: :destroy
  has_many :host_node_stats
  has_many :grid_services, dependent: :destroy
  has_many :grid_secrets, dependent: :delete
  has_many :containers, dependent: :delete
  has_many :container_logs
  has_many :container_stats
  has_many :audit_logs
  has_many :event_logs
  has_many :registries, dependent: :delete
  has_many :stacks, dependent: :destroy
  has_many :grid_domain_authorizations, dependent: :delete
  has_many :networks, dependent: :delete
  has_many :volumes, dependent: :destroy
  has_many :certificates
  has_and_belongs_to_many :users
  embeds_one :grid_logs_opts, class_name: 'GridLogsOpts'

  index({ name: 1 }, { unique: true })
  index({ token: 1 }, { unique: true })

  before_create :set_token
  after_create :create_default_network
  after_create :create_default_stack

  # @return [String]
  def to_path
    self.name
  end

  # @return [String]
  def domain
    "#{self.name}.kontena.local"
  end

  def to_json(args = {})
    super(args.merge({:except => [:_id] }))
  end

  # @return [Array<Integer>]
  def reserved_node_numbers
    self.host_nodes.distinct(:node_number)
  end

  # @return [Array<Integer>]
  def free_node_numbers
    NODE_NUMBERS.to_a - self.reserved_node_numbers
  end

  # @param name [String]
  # @param ensure_unique_name [Boolean] rename node with suffix on name conflicts
  # @raise [RuntimeError]
  # @raise [Mongoid::Errors::ValidationsError]
  # @raise [Mongo::Error::OperationFailure]
  # @return [HostNode] with unique name, node_number
  def create_node!(name, ensure_unique_name: false, **attrs)
    node = HostNode.new(grid: self, name: name, **attrs)
    duplicate_name = false

    begin
      unless node.node_number = self.free_node_numbers.first
        raise 'Node numbers not available. Grid is full?'
      end

      if duplicate_name
        node.name = "#{name}-#{node.node_number}"
      end

      node.save!

      return node

    rescue Mongo::Error::OperationFailure => exc
      raise unless exc.message =~ /^E11000 duplicate key error/

      if self.host_nodes.where(node_number: node.node_number).exists?
        warn "retry node #{name} node_number allocation on error: #{exc}"
        retry
      elsif ensure_unique_name && self.host_nodes.where(name: node.name).exists?
        warn "rename node #{name} on name conflict: #{exc}"
        duplicate_name = true
        retry
      else
        raise
      end
    end
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

  private

  def set_token
    self.token ||= SecureRandom.base64(64)
  end

  def create_default_network
    Network.create!(
      grid: self,
      name: 'kontena',
      subnet: self.subnet,
      multicast: true,
      internal: false)
  end

  def create_default_stack
    self.stacks.create(name: Stack::NULL_STACK)
  end
end
