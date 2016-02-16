require "securerandom"

module AccessTokens
  class Create < Mutations::Command

    required do
      model :user
      array :scopes do
        string in: %w(user)
      end
    end

    optional do
      string :type
    end

    def execute
      AccessToken.create!(
        user: self.user,
        token_type: self.type,
        scopes: self.scopes,
        expires_at: 3.hours.from_now,
        token: "kontena-#{SecureRandom.base64(64)}",
        refresh_token: SecureRandom.base64(64)
      )
    end
  end
end
