module Grids
  class AssignUser < Mutations::Command
    required do
      model :current_user, class: User
      model :user
      model :grid
    end

    def validate
      unless current_user.grids.include?(grid)
        add_error(:grid, :invalid, 'Invalid grid')
      end
    end

    def execute
      user.grids << grid
      grid.reload.users
    end
  end
end