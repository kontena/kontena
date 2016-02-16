require 'json_serializer'

class GridSerializer < JsonSerializer
  attribute :id
  attribute :name
  attribute :token
  attribute :initial_size
  attribute :node_count
  attribute :service_count
  attribute :container_count
  attribute :user_count
  attribute :cores
  attribute :memory

  def id
    object.to_path
  end

  def node_count
    object.host_nodes.count
  end

  def service_count
    object.grid_services.visible.count
  end

  def container_count
    object.containers.count
  end

  def user_count
    object.users.count
  end

  def memory
    object.total_memory
  end

  def cores
    object.number_of_cores
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