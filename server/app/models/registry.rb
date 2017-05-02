require_relative '../helpers/to_path_cache_helper'
class Registry
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :url, type: String
  field :username, type: String
  field :password, type: String
  field :email, type: String

  belongs_to :grid

  index({ grid_id: 1 })

  validates_uniqueness_of :name, scope: [:grid_id]

  include ToPathCacheHelper
  def build_path
    "#{self.grid.try(:name)}/#{self.name}"
  end

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
