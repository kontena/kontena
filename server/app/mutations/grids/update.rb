module Grids
  class Update < Mutations::Command

    required do
      model :grid
      string :name, min_length: 3, matches: /^(\w|-)+$/
    end

    def execute
      grid.update_attributes(name: self.name)
      if grid.errors.size > 0
        grid.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return
      end

      grid
    end

  end
end
