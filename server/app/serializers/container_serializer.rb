require 'json_serializer'

class ContainerSerializer < JsonSerializer

  attribute :id
  attribute :name
  attribute :container_id
  attribute :container_type
  attribute :grid_id
  attribute :node
  attribute :service_id
  attribute :created_at
  attribute :updated_at
  attribute :started_at
  attribute :finished_at
  attribute :deleted_at
  attribute :status
  attribute :state
  attribute :deploy_rev
  attribute :image
  attribute :env
  attribute :volumes
  attribute :overlay_cidr

  attribute :network_settings

  def service_id
    object.grid_service.to_path if object.grid_service
  end

  def grid_id
    object.grid.name
  end

  def id
    object.to_path
  end

  def overlay_cidr
    object.overlay_cidr.to_s if object.overlay_cidr
  end

  def node
    HostNodeSerializer.new(object.host_node).to_hash if object.host_node
  end

  def to_hash
    super
  end

  def serializable_object
    return nil unless @object

    if @object.kind_of?(Enumerable)
      @object.to_a.map { |item| self.class.new(item).to_hash }
    else
      to_hash
    end
  end

end