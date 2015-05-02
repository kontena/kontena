class HostNode
  include Mongoid::Document
  include Mongoid::Timestamps

  field :node_id, type: String
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

  belongs_to :grid
  has_many :containers, dependent: :destroy
  has_and_belongs_to_many :images

  index({ grid_id: 1 })
  index({ node_id:  1 })
  index({ labels:  1 })

  scope :connected, -> { where(connected: true) }

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
      swap_limit: attrs['SwapLimit']
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
end
