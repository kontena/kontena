module Volumes
  class Create < Mutations::Command

    required do
      model :grid, class: Grid
      string :scope, matches: /instance|stack|grid/
      string :name  # TODO Force same rules for naming as docker
      string :driver
    end

    optional do
      model :driver_opts, class: Hash
    end

    def validate
      # These are not the validations you are looking for
    end

    def execute
      volume = Volume.create(
        grid: self.grid,
        name: self.name,
        scope: self.scope,
        driver: self.driver,
        driver_opts: self.driver_opts
      )

      unless volume.save
        volume.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return
      end

      volume
    end

  end

end
