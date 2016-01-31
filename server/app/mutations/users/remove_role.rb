module Users
  class RemoveRole < Mutations::Command
    required do
      model :current_user, class: User
      model :user
      model :role
    end

    def validate
      if role && !current_user.can_unassign?(role)
        add_error(:current_user, :invalid, 'Operation not allowed')
      end

      if role.master_admin? && role.users.count == 1
        add_error(:role, :invalid, 'Not allowed to remove last user from Master admin role')
      end
    end

    def execute
      user.roles.delete(role)
      user
    end
  end
end
