class RoleAuthorizer < ApplicationAuthorizer
  def self.creatable_by?(user)
    user.master_admin?
  end

  def self.assignable_by?(user)
    user.master_admin?
  end

  def self.unassignable_by?(user)
    user.master_admin?
  end
end