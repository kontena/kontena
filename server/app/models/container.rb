require 'ipaddr'
require_relative 'event_stream'
class Container
  include Mongoid::Document
  include Mongoid::Timestamps
  include EventStream

  field :container_id, type: String
  field :name, type: String
  field :driver, type: String
  field :exec_driver, type: String
  field :image, type: String
  field :image_version, type: String
  field :cmd, type: Array, default: []
  field :env, type: Array, default: []
  field :labels, type: Hash, default: {}
  field :hostname, type: String
  field :domainname, type: String
  field :network_settings, type: Hash, default: {}
  field :networks, type: Hash, default: {}
  field :state, type: Hash, default: {}
  field :finished_at, type: Time
  field :started_at, type: Time
  field :deleted_at, type: Time
  field :volumes, type: Array, default: []
  field :deploy_rev, type: String
  field :service_rev, type: String
  field :container_type, type: String, default: 'container'
  field :instance_number, type: Integer

  field :health_status, type: String
  field :health_status_at, type: Time

  validates_uniqueness_of :container_id, scope: [:host_node_id], allow_nil: true

  belongs_to :grid
  belongs_to :grid_service
  belongs_to :host_node
  has_many :container_logs
  has_many :container_stats

  index({ grid_id: 1 })
  index({ grid_service_id: 1 })
  index({ host_node_id: 1 })
  index({ updated_at: 1 })
  index({ deleted_at: 1 }, {sparse: true})
  index({ container_id: 1 })
  index({ state: 1 })
  index({ name: 1 })
  index({ instance_number: 1 })

  default_scope -> { where(deleted_at: nil, container_type: 'container') }
  scope :deleted, -> { where(deleted_at: {'$ne' => nil}) }
  scope :volumes, -> { where(deleted_at: nil, container_type: 'volume') }

  def to_path
    if self.host_node
      "#{self.host_node.to_path}/#{self.name}"
    else
      self.name
    end
  end

  def ip_address
    ip = nil
    unless self.networks.empty?
      overlay_cidr = self.networks.dig('kontena', 'overlay_cidr')
      ip = overlay_cidr.split('/')[0] if overlay_cidr
    end
    ip
  end

  ##
  # @return [String]
  def status
    return 'deleted'.freeze if self.deleted_at

    s = self.state
    if s['paused']
      'paused'.freeze
    elsif s['restarting']
      'restarting'.freeze
    elsif s['dead']
      'dead'.freeze
    elsif s['running']
      'running'.freeze
    elsif s['oom_killed']
      'oom_killed'.freeze
    else
      'stopped'.freeze
    end
  end

  def mark_for_delete
    self.set(:deleted_at => Time.now.utc)
  end

  def running?
    self.status == 'running'
  end

  def stopped?
    self.status == 'stopped'
  end

  def paused?
    self.status == 'paused'
  end

  def ephemeral?
    self.volumes.nil? || self.volumes.size == 0
  end

  def deleted?
    self.status == 'deleted'
  end

  def up_to_date?
    self.image_version == self.grid_service.image.image_id && self.created_at > self.grid_service.updated_at
  end

  # @param [String] status
  def set_health_status(status)
    health_status_changed = self.health_status != status
    self.set(
      health_status: status,
      health_status_at: Time.now
    )
    publish_update_event if health_status_changed
  end

  # @param [BSON::ObjectId] grid_id
  # @param [Hash] match
  # @return [Array<Hash>]
  def self.counts_for_grid_services(grid_id, match = {})
    match = { :grid_id => grid_id, :container_type => 'container'}.merge(match)
    self.collection.aggregate([
      { :$match => match },
      { :$group => { _id: "$grid_service_id", total: {:$sum => 1} } }
    ])
  end

  # @return [String]
  def instance_name
    service = self.label('io.kontena.service.name'.freeze)
    instance = self.instance_number || '0'.freeze

    name = "#{stack_name}-"
    name << "#{service}-" if service
    name << "#{instance}"

    name
  end

  # @return [String]
  def stack_name
    self.label('io.kontena.stack.name') || Stack::NULL_STACK
  end

  # @param [String] name
  # @return [String, NilClass]
  def label(name)
    key = name.gsub(/\./, ';'.freeze)
    self.labels[key]
  end

  # @param [GridService] service
  # @param [Integer] instance_number
  def self.service_instance(service, instance_number)
    match = {
      grid_service_id: service.id,
      instance_number: instance_number.to_i
    }
    where(match)
  end

  def publish_create_event
    return unless self.grid_service

    event = {
      event: 'update',
      type: 'GridService',
      object: GridServiceSerializer.new(self.grid_service).to_hash
    }
    publish_async(event)
  end

  def publish_update_event(relation_object = nil)
    return unless self.grid_service

    event = {
      event: 'update',
      type: 'GridService',
      object: GridServiceSerializer.new(self.grid_service).to_hash
    }
    publish_async(event)
  end

  def publish_destroy_event
    return unless self.grid_service

    event = {
      event: 'update',
      type: 'GridService',
      object: GridServiceSerializer.new(self.grid_service).to_hash
    }
    publish_async(event)
  end
end
