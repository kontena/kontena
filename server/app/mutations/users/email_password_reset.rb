module Users
  class EmailPasswordReset < Mutations::Command
    required do
      model :user
    end

    def execute
      self.user.update_attribute(:password_reset_token, SecureRandom.base64(64))
      UserMailer.delay.password_reset_email(self.user.id)

      self.user
    end
  end
end