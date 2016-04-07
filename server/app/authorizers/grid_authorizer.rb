class GridAuthorizer < ApplicationAuthorizer
  def self.creatable_by?(user)
    user.master_admin?
  end

  def updatable_by?(user)
    user.master_admin? || user.grid_admin?(resource)
  end

  def deletable_by?(user)
    user.master_admin?
  end

end