module Users
  class RemoveRole < Mutations::Command
    required do
      model :current_user, class: User
      model :user
      string :role
    end

    optional do
      model :role_instance, class: Role
    end

    def validate
      self.role_instance = Role.find_by(name: role)

      unless role_instance
        add_error(:role, :not_found, "Role '#{role}' not found")
        return false
      end

      unless current_user.can_unassign?(role_instance)
        add_error(:current_user, :invalid, 'Operation not allowed')
      end

      if role_instance.master_admin? && role_instance.users.count == 1
        add_error(:role, :invalid, 'Not allowed to remove last user from Master admin role')
      end
    end

    def execute
      user.roles.delete(role_instance)
      user
    end
  end
end
