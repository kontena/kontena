require_relative '../grid_services/helpers'

module GridSecrets
  module Common
    include GridServices::Helpers
    include Workers
    include Logging

    ##
    # @param [GridSecret]
    def refresh_grid_services(secret)
      secret.grid.grid_services.where(:'secrets.secret' => secret.name).each do |grid_service|
        info "force service #{grid_service.to_path} update for changed secret #{secret.to_path}"

        update_grid_service(grid_service, force: true)
      end
    end
  end
end
