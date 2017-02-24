class Volume
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :scope, type: String # TODO: Should be enum once scope names are fixed
  field :driver, type: String, default: 'local'
  field :driver_opts, type: Hash, default: {}
  field :external, type: Boolean

  belongs_to :grid
  belongs_to :stack, inverse_of: :volumes
  belongs_to :external_volume

  index({ grid_id: 1 })
  index({ name: 1 })
  index({ stack_id: 1 })

  validates_presence_of :name, :scope, :grid_id
  validates_uniqueness_of :name, scope: [:grid_id, :stack_id]

  def to_path
    return "#{stack.name}/#{name}" if stack
    "#{name}"
  end

  def stacked_name
    if default_stack?
      return self.name
    end
    "#{stack.name}.#{self.name}"
  end

  def name_for_service(service, instance_number)
    if stack
      case self.scope
      when 'node'
        self.stacked_name
      when 'instance-private'
        "#{self.stacked_name}-#{service.name}-#{instance_number}"
      when 'instance-shared'
        "#{self.stacked_name}-#{instance_number}"
      end
    else
      name
    end
  end

  # @return [Boolean]
  def default_stack?
    self.stack.try(:name).to_s == Stack::NULL_STACK
  end

end
