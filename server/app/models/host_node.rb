require 'ipaddr'
require 'securerandom'
require_relative 'event_stream'

class HostNode
  include Mongoid::Document
  include Mongoid::Timestamps
  include EventStream

  module Availability
    ACTIVE = 'active'.freeze
    DRAIN = 'drain'.freeze
  end

  Error = Class.new(StandardError)

  field :node_id, type: String
  field :node_number, type: Integer
  field :name, type: String
  field :token, type: String
  field :os, type: String
  field :docker_root_dir, type: String
  field :driver, type: String
  field :execution_driver, type: String
  field :ipv4_forwarding, type: Integer
  field :kernel_version, type: String
  field :labels, type: Array, default: []
  field :mem_total, type: Integer
  field :mem_limit, type: Integer
  field :cpus, type: Integer
  field :swap_limit, type: Integer
  field :connected, type: Boolean, default: false
  field :public_ip, type: String
  field :private_ip, type: String
  field :last_seen_at, type: Time
  field :agent_version, type: String
  field :docker_version, type: String
  field :connected_at, type: Time
  field :disconnected_at, type: Time
  field :updated, type: Boolean, default: false # true => node sent /nodes/update after connecting; false => node attributes may be out of date even if connected
  field :availability, type: String, default: Availability::ACTIVE

  embeds_many :volume_drivers, class_name: 'HostNodeDriver'
  embeds_many :network_drivers, class_name: 'HostNodeDriver'
  embeds_one :websocket_connection, class_name: 'HostNodeConnection'

  belongs_to :grid
  has_many :grid_service_instances, dependent: :nullify
  has_many :event_logs
  has_many :containers
  has_many :container_stats
  has_many :host_node_stats
  has_many :volume_instances, dependent: :destroy
  has_and_belongs_to_many :images

  validates :node_number, presence: true
  validates :name, presence: true
  validates_length_of :token, minimum: 16, maximum: 256, allow_nil: true

  index({ grid_id: 1 })
  index({ node_id: 1 }, { unique: true, sparse: true })
  index({ labels: 1 })
  index({ grid_id: 1, name: 1 }, { unique: true })
  index({ grid_id: 1, node_number: 1 }, { unique: true })
  index({ token: 1 }, { unique: true, sparse: true })

  scope :connected, -> { where(connected: true) }

  after_destroy do |node|
    node.containers.unscoped.destroy
  end

  # @return [String]
  def to_s
    self.name || self.node_id
  end

  def to_path
    "#{self.grid.try(:name)}/#{self.name || self.node_id}"
  end

  # @param [String] name Name of the volume driver
  # @return [HostNodeDriver, nil] Given driver or nil if not found
  def volume_driver(name)
    self.volume_drivers.find_by(name: name)
  end

  ##
  # @param [Hash] attrs
  def attributes_from_docker(attrs)
    self.attributes = {
      os: attrs['OperatingSystem'],
      docker_root_dir: attrs['DockerRootDir'],
      driver: attrs['Driver'],
      execution_driver: attrs['ExecutionDriver'],
      ipv4_forwarding: attrs['IPv4Forwarding'],
      kernel_version: attrs['KernelVersion'],
      mem_total: attrs['MemTotal'],
      mem_limit: attrs['MemoryLimit'],
      cpus: attrs['NCPU'],
      swap_limit: attrs['SwapLimit'],
      public_ip: attrs['PublicIp'],
      private_ip: attrs['PrivateIp'],
      agent_version: attrs['AgentVersion'],
      docker_version: attrs['ServerVersion'],
      volume_drivers: attrs.dig('Drivers', 'Volume') || [],
      network_drivers: attrs.dig('Drivers', 'Network') || [],
    }
    if self.labels.nil? || self.labels.size == 0
      self.labels = attrs['Labels']
    end
  end

  # @return [Boolean]
  def active?
    self.availability == Availability::ACTIVE
  end

  # @return [Boolean]
  def drain?
    self.availability == Availability::DRAIN
  end

  # @return [Symbol]
  def status
    if self.node_id.nil?
      return :created # node created with token, but agent has not yet connected
    elsif !self.connected
      return :offline # not yet connected by NodePlugger, or disconnected by NodeUnplugger
    elsif !self.updated
      return :connecting # connected by NodePlugger, waiting for /nodes/update RPC
    elsif self.drain?
      return :drain
    else
      return :online # connected by NodePlugger, updated by /nodes/update RPC
    end
  end

  # @return [String]
  def websocket_error
    if self.connected
      return nil
    elsif !self.websocket_connection
      return "Websocket is not connected"
    elsif !self.websocket_connection.opened
      # WebsocketBackend#on_open -> Agent::NodePlugger.reject!
      return "Websocket connection rejected at #{self.connected_at} with code #{self.websocket_connection.close_code}: #{self.websocket_connection.close_reason}"
    else
      # WebsocketBackend#on_close -> Agent::NodeUnplugger.unplug!
      return "Websocket disconnected at #{self.disconnected_at} with code #{self.websocket_connection.close_code}: #{self.websocket_connection.close_reason}"
    end
  end


  # @return [Boolean]
  def connected?
    self.connected == true
  end

  # attributes are up to date
  #
  # @return [Boolean]
  def updated?
    self.connected && self.updated
  end

  # @return [Boolean]
  def stateful?
    self.containers.unscoped.any?{|container| container.grid_service && container.grid_service.stateful? }
  end

  ##
  # @param [Integer] timeout
  # @return [RpcClient]
  def rpc_client(timeout = 300)
    RpcClient.new(self.node_id, timeout)
  end

  def initial_member?
    self.node_number <= self.grid.initial_size
  end

  # @param label [String] match label name before =
  # @return [Boolean] label exists
  def has_label?(lookup_name)
    self.labels.to_a.each do |label|
      name, value = label.split('=', 2)

      next if name != lookup_name

      return true
    end
    return false
  end

  # @param label [String] match label name before =
  # @return [String, nil] the label value, or nil if omitted/empty
  def label_value(lookup_name)
    self.labels.to_a.each do |label|
      name, value = label.split('=', 2)

      next if name != lookup_name

      return value
    end
    return nil
  end

  # @return [String]
  def region
    @region ||= label_value('region') || 'default'
  end

  # @return [String]
  def availability_zone
    @availability_zone ||= label_value('az') || 'default'
  end

  # @return [String]
  def host_provider
    @host_provider ||= label_value('provider') || 'default'
  end

  # @return [Boolean]
  def ephemeral?
    @ephemeral ||= has_label?('ephemeral')
  end

  # @return [String] Overlay IP, without subnet mask
  def overlay_ip
    (IPAddr.new(self.grid.subnet) | self.node_number).to_s
  end
end
