module GridSecrets
  module Common
    include Workers
    include Logging

    ##
    # @param [GridSecret]
    def refresh_grid_services(secret)
      secret.grid.grid_services.where(:'secrets.secret' => secret.name).each do |grid_service|

        info "force service #{grid_service.to_path} update for changed secret #{secret.to_path}"

        grid_service.revision += 1
        grid_service.save
      end
    end
  end
end
