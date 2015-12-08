module V1
  class SecretsApi < Roda
    include OAuth2TokenVerifier
    include CurrentUser
    include RequestHelpers
    include Auditor

    route do |r|

      validate_access_token
      require_current_user

      # @param [String] grid_name
      # @param [String] secret_name
      # @return [GridSecret]
      def load_grid_secret(grid_name, secret_name)
        grid = Grid.find_by(name: grid_name)
        halt_request(404, {error: 'Not found'}) if !grid
        grid_secret = grid.grid_secrets.find_by(name: secret_name)
        halt_request(404, {error: 'Not found'}) if !grid_secret

        unless current_user.grid_ids.include?(grid_secret.grid_id)
          halt_request(403, {error: 'Access denied'})
        end

        grid_secret
      end

      # /v1/secrets/:grid_name/:secret_name
      r.on ':grid_name/:secret_name' do |grid_name, secret_name|
        @grid_secret = load_grid_service(grid_name, secret_name)

        # GET /v1/secrets/:grid_name/:secret_name
        r.get do
          r.is do
            render('grid_secret/show')
          end
        end

        # DELETE /v1/secrets/:grid_name/:secret_name
        r.delete do
          r.is do
            audit_event(r, @grid_service.grid, @grid_secret, 'delete')
            {}
          end
        end
      end
    end
  end
end
