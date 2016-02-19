module Grids
  class AssignUser < Mutations::Command
    required do
      model :current_user, class: User
      model :user
      model :grid
    end

    def validate
      unless current_user.can_assign?(self.user, {to: self.grid})
        add_error(:grid, :invalid, 'Operation not allowed')
      end
    end

    def execute
      user.grids << grid
      grid.reload.users
    end
  end
end