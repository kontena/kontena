require 'digest/md5'

class User
  include Mongoid::Document
  include Mongoid::Timestamps

  has_and_belongs_to_many :grids
  has_many :access_tokens, dependent: :delete
  has_many :audit_logs

  field :email, type: String
  field :external_id, type: String
  validates :email,
            uniqueness: true,
            presence: true,
            format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i }

  index({ email: 1 }, { unique: true })

  def name
    self.email
  end

end
