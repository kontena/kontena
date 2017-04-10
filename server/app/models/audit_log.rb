class AuditLog
  include Mongoid::Document
  include Mongoid::Timestamps

  field :resource_name, type: String
  field :resource_type, type: String
  field :resource_id, type: String
  field :event_name, type: String
  field :event_status, type: String
  field :event_description, type: String
  field :user_identity, type: Hash
  field :source_ip, type: String
  field :user_agent, type: String
  field :request_parameters, type: Hash
  field :request_body, type: String

  belongs_to :grid
  belongs_to :user
  belongs_to :grid_service

  index({ grid_id: 1 }, { background: true })
end
