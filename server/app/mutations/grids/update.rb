require_relative 'common'

module Grids
  class Update < Mutations::Command
    include Common

    required do
      model :grid
      model :user
    end

    common_validations

    def validate
      add_error(:user, :invalid, 'Operation not allowed') unless user.can_update?(grid)

      validate_common
    end

    def execute
      execute_common(self.grid)

      unless self.grid.save
        self.grid.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return
      end

      Celluloid::Future.new do
        self.notify_nodes(self.grid)
        self.reschedule_grid(self.grid)
      end

      self.grid
    end
  end
end
