require 'ipaddr'
require_relative 'event_stream'

class HostNode
  include Mongoid::Document
  include Mongoid::Timestamps
  include EventStream

  Error = Class.new(StandardError)

  field :node_id, type: String
  field :node_number, type: Integer
  field :name, type: String
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

  embeds_many :volume_drivers, class_name: 'HostNodeDriver'
  embeds_many :network_drivers, class_name: 'HostNodeDriver'

  belongs_to :grid
  has_many :grid_service_instances, dependent: :nullify
  has_many :event_logs
  has_many :containers
  has_many :container_stats
  has_many :host_node_stats
  has_many :volume_instances, dependent: :destroy
  has_and_belongs_to_many :images

  after_save :reserve_node_number, :ensure_unique_name

  index({ grid_id: 1 })
  index({ node_id: 1 })
  index({ labels: 1 })
  index({ grid_id: 1, node_number: 1 }, { unique: true, sparse: true })

  scope :connected, -> { where(connected: true) }

  after_destroy do |node|
    node.containers.unscoped.destroy
  end

  def to_path
    "#{self.grid.try(:name)}/#{self.name}"
  end

  ##
  # @param [Hash] attrs
  def attributes_from_docker(attrs)
    self.attributes = {
      node_id: attrs['ID'],
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
    if self.name.nil?
      self.name = attrs['Name']
    end
    if self.labels.nil? || self.labels.size == 0
      self.labels = attrs['Labels']
    end
  end

  # @return [Boolean]
  def connected?
    self.connected == true
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
    return false if self.node_number.nil?
    return true if self.node_number <= self.grid.initial_size
    false
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

  private

  def reserve_node_number
    return unless self.node_number.nil?
    return if self.grid.nil?

    free_numbers = self.grid.free_node_numbers
    begin
      node_number = free_numbers.shift
      raise Error.new('Node numbers not available. Grid is full?') if node_number.nil?
      self.update_attribute(:node_number, node_number)
    rescue Mongo::Error::OperationFailure
      retry
    end
  end

  def ensure_unique_name
    return if self.name.to_s.empty?
    return unless self.grid
    return unless self.grid.respond_to?(:host_nodes)

    if self.grid.host_nodes.unscoped.where(:id.ne => self.id, name: self.name).count > 0
      self.set(name: "#{self.name}-#{self.node_number}")
    end
  end
end
