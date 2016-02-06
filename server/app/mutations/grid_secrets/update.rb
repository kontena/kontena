module GridSecrets
  class Update < Mutations::Command

    required do
      model :grid_secret, class: GridSecret
      string :value
    end

    def execute
      grid_secret.value = value
      grid_secret.save
      if grid_secret.errors.size > 0
        grid_secret.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return
      end

      grid_secret
    end
  end
end
