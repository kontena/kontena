class Grid
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :token, type: String
  field :discovery_url, type: String
  field :initial_size, type: Integer

  has_many :host_nodes
  has_many :grid_services
  has_many :containers
  has_many :container_logs
  has_many :container_stats
  has_many :audit_logs
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

  private

  def set_token
    self.token = SecureRandom.base64(64)
  end
end
