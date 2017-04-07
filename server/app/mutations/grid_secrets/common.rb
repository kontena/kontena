module GridSecrets
  module Common
    include Workers

    ##
    # @param [GridSecret]
    def refresh_grid_services(secret)
      secret.grid.grid_services.where(:'secrets.secret' => secret.name).each do |grid_service|
        grid_service.set(updated_at: Time.now.utc)
      end
    end
  end
end
