module Grids
  class AddCustomPeer < Mutations::Command
    required do
      model :current_user, class: User
      model :grid
      string :peer
    end

    def validate
      unless current_user.grids.include?(grid)
        add_error(:grid, :invalid, 'Invalid grid')
      end
    end

    def execute
      grid.add_to_set(custom_peers: peer)
      grid.reload
    end
  end
end
