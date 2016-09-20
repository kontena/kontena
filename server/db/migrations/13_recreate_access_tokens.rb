class RecreateAccessTokens < Mongodb::Migration
  def self.up
    dummy = AccessToken.create(
      user: User.create(email: 'jorma@jorma.com'),
      scopes: ['user'],
      token: 'abcd12345'
    )
    dummy.user.roles << Role.master_admin
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

