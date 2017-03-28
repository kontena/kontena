module Users
  class RemoveRole < Mutations::Command

    attr_reader :role_instance

    required do
      model :current_user, class: User
      model :user
      string :role
    end

    def validate
      @role_instance = Role.find_by(name: role)

      if role_instance.nil?
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
      user.publish_update_event # relation callback has bug so we have to explicitly run callback
      user
    end
  end
end
