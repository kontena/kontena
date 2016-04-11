module Users
  class Remove < Mutations::Command
    required do
      model :user
      model :current_user, class: User
    end

    def validate
      unless self.current_user.can_delete?(User)
        add_error(:user, :invalid, 'Operation not allowed')
      end
      if current_user == user
        add_error(:user, :invalid, 'Cannot remove itself')
      end
    end

    def execute
      user.destroy
      user
    end
  end
end
