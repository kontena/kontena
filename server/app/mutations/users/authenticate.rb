require_relative '../access_tokens/create'

module Users
  class Authenticate < Mutations::Command
    VALID_SCOPES = %w( user )

    required do
      string :username
      string :password
      string :grant_type, in: %w( password )
      array :scope, class: String
    end

    def validate
      if self.scope.size == 0
        add_error(:scope, :invalid, 'Scope is required')
      end
      if self.scope.any?{|s| !VALID_SCOPES.include?(s) }
        add_error(:scope, :invalid, 'Invalid scope')
      end
    end

    def execute
      user = User.find_by(email: self.username)
      if user.nil? || !user.authenticate(self.password)
        add_error(:username, :invalid, 'Invalid username or password')
        return
      end

      AccessTokens::Create.run(
        user: user,
        scopes: self.scope
      ).result
    end
  end
end
