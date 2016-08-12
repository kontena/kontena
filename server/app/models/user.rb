require 'digest/md5'
require 'bcrypt'

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
  field :name,  type: String
  field :external_id, type: String
  field :member_of, type: Array
  field :invite_code, type: String
  field :password_hash, type: String

  validates :email,
            uniqueness: true,
            presence: true,
            format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i },
            unless: :is_local_admin?

  index({ email: 1 }, { unique: true })
  index({ external_id: 1 }, { unique: true })
  index({ invite_code: 1}, { unique: true, sparse: true })

  attr_accessor :password

  set_callback :save, :before do |doc|
    if doc[:email] == 'admin' && doc.password
      doc.password_hash = BCrypt::Password.create(doc.password)
    end
  end

  # Fake setter. When true, an invite code will be generated
  def with_invite=(boolean)
    if boolean
      self[:invite_code] = SecureRandom.hex(4)
    end
  end

  def is_local_admin?
    self[:email] == 'admin'
  end

  def self.find_admin(password)
    admin = where(email: 'admin').first
    return nil unless admin
    return nil unless admin.password_hash
    if BCrypt::Password.new(admin.password_hash) == password
      admin
    else
      nil
    end
  end

  def name
    self[:name] || self[:email]
  end

  def member_of?(org_name)
    return false if self.member_of.nil?
    return false if self.member_of.empty?
    self.member_of.include?(org_name)
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
    self.email == 'admin' || self.in_role?(Role::MASTER_ADMIN_ROLE)
  end

  def grid_admin?(grid)
    self.in_role?(Role::GRID_ADMIN_ROLE) && self.grids.include?(grid)
  end
end
