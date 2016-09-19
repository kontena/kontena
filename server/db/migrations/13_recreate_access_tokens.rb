class RecreateAccessTokens < Mongodb::Migration
  def self.up
    access_tokens = AccessToken.all.to_a
    AccessToken.collection.drop
    AccessToken.create_indexes

    access_tokens.each do |token|
      new_token = AccessToken.create(
        user: token.user,
        token_plain: token.token,
        expires_at: nil,
        refresh_token: nil,
        scopes: token.scopes,
        internal: true
      )
    end
  end
end

