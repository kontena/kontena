require 'digest/md5'

class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include Authority::UserAbilities
  include Authority::Abilities

  has_and_belongs_to_many :grids
  has_many :access_tokens, dependent: :delete
  has_many :audit_logs
  has_and_belongs_to_many :roles

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

  ##
  # @return [Mongoid::Criteria]
  def accessible_grids
    if self.master_admin?
      Grid.all
    else
      self.grids
    end
  end

  ##
  # @param [String] role
  def in_role?(role)
    self.roles.where(name: role).exists?
  end

  def master_admin?
    self.in_role?(Role::MASTER_ADMIN_ROLE)
  end

  def grid_admin?(grid)
    self.in_role?(Role::GRID_ADMIN_ROLE) && self.grids.include?(grid)
  end
end
