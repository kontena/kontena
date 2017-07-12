module Grids
  class UnassignUser < Mutations::Command
    required do
      model :current_user, class: User
      model :user
      model :grid
    end

    def validate
      unless current_user.can_assign?(self.user, {to: self.grid})
        add_error(:grid, :invalid, 'Operation not allowed')
      end

      unless grid.users.include?(user)
        add_error(:user, :invalid, 'Invalid user')
        return
      end

      if grid.users.count == 1
        add_error(:grid, :invalid, 'Cannot remove last user')
      end
    end

    def execute
      user.grids.delete(grid)
      user.publish_update_event
      grid.reload.users
    end
  end
end
