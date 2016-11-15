require 'ipaddr'

class HostNode
  include Mongoid::Document
  include Mongoid::Timestamps

  class Error < StandardError
  end

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

  attr_accessor :schedule_counter

  belongs_to :grid
  has_many :containers, dependent: :destroy
  has_many :host_node_stats
  has_and_belongs_to_many :images

  after_save :reserve_node_number, :ensure_unique_name

  index({ grid_id: 1 })
  index({ node_id: 1 })
  index({ labels: 1 })
  index({ grid_id: 1, node_number: 1 }, { unique: true, sparse: true })

  scope :connected, -> { where(connected: true) }

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
      docker_version: attrs['ServerVersion']
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

  # @return [Integer]
  def schedule_counter
    @schedule_counter ||= 0
  end

  # @return [String]
  def region
    if @region.nil?
      @region = 'default'.freeze
      self.labels.to_a.each do |label|
        if match = label.match(/^region=(.+)/)
          @region = match[1]
        end
      end
    end
    @region
  end

  def initial_member?
    return false if self.node_number.nil?
    return true if self.node_number <= self.grid.initial_size
    false
  end

  # @return [String]
  def availability_zone
    if @availability_zone.nil?
      @availability_zone = 'default'.freeze
      self.labels.to_a.each do |label|
        if match = label.match(/^az=(.+)/)
          @availability_zone = match[1]
        end
      end
    end
    @availability_zone
  end

  # @return [String]
  def host_provider
    if @host_provider.nil?
      @host_provider = 'default'.freeze
      self.labels.to_a.each do |label|
        if match = label.match(/^provider=(.+)/)
          @host_provider = match[1]
        end
      end
    end
    @host_provider
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
    rescue Moped::Errors::OperationFailure => exc
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
