require "securerandom"

module AccessTokens
  class Create < Mutations::Command

    required do
      model :user
      integer :expires_in
      string :access_token
      array :scopes do
        string in: %w(user)
      end
    end

    def execute
      AccessToken.create!(
        user: self.user,
        scopes: self.scopes,
        expires_at: 3.hours.from_now,
        token_type: 'bearer',
        token: self.access_token,
        refresh_token: nil
      )
    end
  end
end
