class Role
  include Mongoid::Document
  include Mongoid::Timestamps
  include Authority::Abilities

  has_and_belongs_to_many :users

  MASTER_ADMIN_ROLE = 'master_admin'
  USER_ADMIN_ROLE = 'user_admin'
  GRID_ADMIN_ROLE = 'grid_admin'

  field :name, type: String
  field :description, type: String

  index({ name: 1 }, { unique: true })

  validates_presence_of :name, :description
  validates :name,
            uniqueness: true

  def master_admin?
    self.name == MASTER_ADMIN_ROLE
  end

  def user_admin?
    self.name == USER_ADMIN_ROLE
  end

  def self.master_admin
    self.find_by(name: MASTER_ADMIN_ROLE)
  end
end
