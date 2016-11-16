class StackRevision
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :version, type: Integer, default: 1
  field :services, type: Array

  belongs_to :stack

  index({ stack_id: 1 })

  before_create :increase_version

  private

  def increase_version
    prev = self.stack.stack_revisions.order_by(version: -1).first
    if prev
      self.version = prev.version + 1
    else
      self.version = 1
    end
  end
end
