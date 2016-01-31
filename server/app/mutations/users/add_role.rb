module Users
  class AddRole < Mutations::Command
    required do
      model :current_user, class: User
      model :user
      model :role
    end

    def validate
      if role && !current_user.can_assign?(role)
        add_error(:current_user, :invalid, 'Operation not allowed')
      end
      if role.nil?
        add_error(:role, :invalid, 'Invalid role')
      end
    end

    def execute
      user.roles << role
      user
    end

  end
end
