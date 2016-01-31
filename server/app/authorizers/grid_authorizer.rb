class GridAuthorizer < ApplicationAuthorizer
  def self.creatable_by?(user)
    user.master_admin?
  end

end