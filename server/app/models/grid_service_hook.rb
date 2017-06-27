class GridServiceHook
  include Mongoid::Document

  field :name, type: String
  field :type, type: String
  field :cmd, type: String
  field :instances, type: Array, default: ['*']
  field :oneshot, type: Boolean, default: false
  field :done, type: Array, default: []

  embedded_in :grid_service

  # @param [Integer, String] instance_number
  # @return [Boolean]
  def done_for?(instance_number)
    return false unless self.oneshot
    self.done.include?(instance_number.to_s)
  end
end
