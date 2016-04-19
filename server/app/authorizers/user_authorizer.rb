class UserAuthorizer < ApplicationAuthorizer
  def self.creatable_by?(user)
    user.master_admin?
  end

  def self.readable_by?(user)
    user.master_admin?
  end

  def self.assignable_by?(user, options)
    grid = options[:to]
    user.master_admin? || user.grid_admin?(grid)
  end

  def self.deletable_by?(user)
    user.master_admin?
  end
end
