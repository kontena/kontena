module Users
  class Invite < Mutations::Command
    required do
      model :user
      string :email, matches: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
    end

    def validate
      unless self.user.can_create?(User)
        add_error(:user, :invalid, 'Operation not allowed')
      end
    end

    def execute
      user = User.find_or_create_by(email: email)
      if user.errors.size > 0
        user.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return
      end
      user
    end
  end
end
