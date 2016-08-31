class CreateAuthRequest < Mongodb::Migration
  def self.up
    AuthorizationRequest.create_indexes
  end
end

