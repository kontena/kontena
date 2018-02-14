require "securerandom"

module AccessTokens
  class Create < Mutations::Command

    VALID_INTERNAL_SCOPES = ['user', 'owner']

    required do
      model :user
    end

    optional do
      array :scopes, class: String
      string :scope
      integer :expires_in, nils: true, empty_is_nil: true
      boolean :refreshable, default: true
      boolean :with_code, default: false
      model :current_access_token
      string :token
      string :refresh_token
      string :description, nils: true, empty_is_nil: true
    end

    def validate
      # Accept standard comma separated scope or array
      scopes = self.scope.to_s.gsub(/\s+/, '').split(',')
      if self.scopes.nil? || self.scopes.empty?
        self.scopes = scopes
      end

      if !self.token && self.scopes.any?{|scope| !VALID_INTERNAL_SCOPES.include?(scope)}
        add_error(:scope, :invalid, 'Invalid scope')
      end

      # Scope is always required
      if self.scopes.empty?
        add_error(:scope, :empty, 'Missing scope')
      end

      # Do not allow creating higher privilege tokens
      if self.current_access_token
        if self.scopes.include?('user') && !self.current_access_token.scopes.include?('user')
          add_error(:scope, :invalid, 'Invalid scope')
        end

        if self.scopes.include?('owner') && !self.current_access_token.scopes.include?('owner')
          add_error(:scope, :invalid, 'Invalid scope')
        end

        # TODO: Add other level checks
      end
    end

    def execute
      expires_at = self.expires_in.to_i > 0 ? Time.now.utc + self.expires_in : nil
      attrs = {
        user: self.user,
        scopes: self.scopes,
        expires_at: expires_at,
        with_code: self.with_code,
        description: self.description
      }

      if self.token
        attrs[:internal] = false
        attrs[:token] = self.token
        attrs[:refresh_token] = self.refresh_token
      end

      AccessToken.create!(attrs)
    end
  end
end
