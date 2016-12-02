module Users
  class AddRole < Mutations::Command

    attr_accessor :role_instance

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

      unless current_user.can_assign?(role_instance)
        add_error(:current_user, :invalid, 'Operation not allowed')
      end
    end

    def execute
      user.roles << role_instance
      user
    end
  end
end
