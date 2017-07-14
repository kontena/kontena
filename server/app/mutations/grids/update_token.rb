require_relative 'common'

module Grids
  class UpdateToken < Mutations::Command
    include Common

    required do
      model :grid
      model :user
    end

    def validate
      add_error(:user, :invalid, 'Operation not allowed') unless user.can_update?(grid)
    end

    def generate_secret
      SecureRandom.base64(64)
    end

    def update_weave_secret(grid)
      grid.weave_secret = self.generate_secret
    end

    def execute
      update_weave_secret(self.grid)

      unless self.grid.save
        self.grid.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return
      end

      Celluloid::Future.new do
        notify_nodes(self.grid)
      end

      self.grid
    end
  end
end
