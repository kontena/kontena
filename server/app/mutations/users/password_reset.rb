module Users
  class PasswordReset < Mutations::Command
    required do
      string :token
      string :password, min_length: 8
    end

    def validate
      @user = User.where(password_reset_token: self.token).first
      unless @user
        add_error(:token, :invalid, 'Invalid token')
      end
    end

    def execute
      @user.password = self.password
      @user.password_reset_token = nil
      @user.save!

      @user
    end
  end
end