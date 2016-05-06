module GridSecrets
  module Common
    include Workers

    ##
    # @param [GridSecret]
    def refresh_grid_services(secret)
      secret.grid.grid_services.where(:'secrets.secret' => secret.name).each do |grid_service|
        grid_service.set(updated_at: Time.now.utc)
        worker(:grid_service_scheduler).async.perform(grid_service.id)
      end
    end
  end
end
