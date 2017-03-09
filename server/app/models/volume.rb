class Volume
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :scope, type: String # Mutation enforces scopes
  field :driver, type: String
  field :driver_opts, type: Hash, default: {}
  field :external, type: Boolean

  belongs_to :grid

  index({ grid_id: 1 })
  index({ name: 1 })
  index({ stack_id: 1 })

  validates_presence_of :name, :scope, :grid_id
  validates_uniqueness_of :name, scope: [:grid_id, :stack_id]

  def to_path
    "#{self.grid.try(:name)}/#{self.name}"
  end

  def name_for_service(service, instance_number)

    case self.scope
    when 'instance'
      "#{service.name_with_stack}.#{self.name}-#{instance_number}"
    when 'stack'
      "#{service.stack.name}.#{self.name}"
    when 'grid'
      self.name
    end
  end

end
