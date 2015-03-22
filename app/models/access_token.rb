class AccessToken
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :user
  validates_presence_of :scopes, :user

  field :token_type, type: String
  field :token, type: String
  field :refresh_token, type: String
  field :expires_at, type: Time
  field :scopes, type: Array

  index({ user_id: 1 })
  index({ token: 1 }, { unique: true })
  index({ refresh_token: 1 }, { unique: true, sparse: true })
  index({ expires_at: 1 }, { unique: true, sparse: true })
end
