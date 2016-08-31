class RecreateAccessTokens < Mongodb::Migration
  def self.up
    AccessToken.collection.drop
    AccessToken.create_indexes
  end
end

