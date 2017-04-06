require_relative 'common'

module GridSecrets
  class Update < Mutations::Command
    include Common

    required do
      model :grid_secret, class: GridSecret
      string :value
    end

    def execute
      grid_secret.value = value
      return grid_secret unless grid_secret.changed?
      
      grid_secret.save
      if grid_secret.errors.size > 0
        grid_secret.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return
      end
      self.refresh_grid_services(grid_secret)
      grid_secret
    end
  end
end
