class Volume
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :scope, type: String # TODO: Should be enum once scope names are fixed
  field :driver, type: String, default: 'local'
  field :driver_opts, type: Hash, default: {}

  belongs_to :grid
  belongs_to :stack

  index({ grid_id: 1 })
  index({ name: 1 })
  index({ stack_id: 1 })

  validates_presence_of :name, :scope, :grid_id, :stack_id
  validates_uniqueness_of :name, scope: [:grid_id, :stack_id]

  def to_path
    "#{grid.name}/#{stack.name}/#{name}"
  end

  def stacked_name
    "#{stack.name}.#{self.name}"
  end

  def name_for_service(service, instance_number)
    case self.scope
    when 'node'
      self.stacked_name
    when 'instance-private'
      "#{self.stacked_name}-#{service.name}-#{instance_number}"
    when 'instance-shared'
      "#{self.stacked_name}-#{instance_number}"
    end
  end

end
