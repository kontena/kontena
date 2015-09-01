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

  belongs_to :grid
  has_many :containers, dependent: :destroy
  has_and_belongs_to_many :images

  after_save :reserve_node_number

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
      name: attrs['Name'],
      os: attrs['OperatingSystem'],
      docker_root_dir: attrs['DockerRootDir'],
      driver: attrs['Driver'],
      execution_driver: attrs['ExecutionDriver'],
      ipv4_forwarding: attrs['IPv4Forwarding'],
      kernel_version: attrs['KernelVersion'],
      labels: attrs['Labels'],
      mem_total: attrs['MemTotal'],
      mem_limit: attrs['MemoryLimit'],
      cpus: attrs['NCPU'],
      swap_limit: attrs['SwapLimit'],
      public_ip: attrs['PublicIp'],
      private_ip: attrs['PrivateIp']
    }
  end

  def connected?
    self.connected == true
  end

  ##
  # @param [Integer] timeout
  # @return [RpcClient]
  def rpc_client(timeout = 300)
    RpcClient.new(self.node_id, timeout)
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
end
