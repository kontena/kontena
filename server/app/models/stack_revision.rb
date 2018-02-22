class StackRevision
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :stack_name, type: String
  field :registry, type: String
  field :source, type: String
  field :variables, type: Hash, default: {}
  field :version, type: String
  field :revision, type: Integer, default: 1
  field :expose, type: String
  field :services, type: Array, default: []
  field :volumes, type: Array, default: []
  field :metadata, type: Hash, default: {}
  field :labels, type: Array, default: []

  belongs_to :stack

  index({ stack_id: 1 })
  index({ labels: 1 })

  before_create :increase_version

  private

  def increase_version
    prev = self.stack.stack_revisions.order_by(revision: -1).first
    if prev
      self.revision = prev.revision + 1
    else
      self.revision = 1
    end
  end
end
