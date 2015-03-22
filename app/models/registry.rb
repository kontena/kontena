class Registry
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :url, type: String
  field :username, type: String
  field :password, type: String
  field :email, type: String

  belongs_to :user

  index({ user_id: 1 })

  validates_uniqueness_of :name, scope: [:user_id]

  ##
  # @return [Hash]
  def to_creds
    {
      username: self.username,
      password: self.password,
      email: self.email
    }
  end
end