module Grids
  class Delete < Mutations::Command

    required do
      model :grid
      model :user
    end

    def validate

      add_error(:user, :invalid, 'Operation not allowed') unless user.can_delete?(grid)
      add_error(:grid, :services_exist, 'Grid has services') if grid.grid_services.exists?
      add_error(:grid, :host_nodes, 'Grid has nodes') if grid.host_nodes.exists?
    end

    def execute
      grid.destroy
      grid.errors.each do |key, message|
        add_error(key, :invalid, message)
      end

    end
  end
end
