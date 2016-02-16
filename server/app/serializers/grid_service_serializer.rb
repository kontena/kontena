require 'json_serializer'

class GridServiceSerializer < JsonSerializer

  attribute :id
  attribute :name
  attribute :image
  attribute :created_at
  attribute :updated_at
  attribute :state
  attribute :stateful
  attribute :container_count
  attribute :cmd
  attribute :entrypoint
  attribute :ports
  attribute :env
  attribute :memory
  attribute :memory_swap
  attribute :cpu_shares
  attribute :volumes
  attribute :volumes_from
  attribute :cap_add
  attribute :cap_drop



  def image
    object.image_name
  end

  def grid_id
    object.grid.name
  end

  def id
    object.to_path
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