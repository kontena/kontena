require_relative 'common'

module GridSecrets
  class Create < Mutations::Command
    include Common

    required do
      model :grid, class: Grid
      string :name, matches: /\A(?!-)(\w|-)+\z/ # do not allow "-" as a first character
      string :value
    end

    def execute
      grid_secret = GridSecret.create(
          grid: self.grid,
          name: self.name,
          value: self.value
      )
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
