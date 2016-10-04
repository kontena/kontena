
module V1
  class ExternalRegistriesApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers

    route do |r|

      validate_access_token
      require_current_user

      def load_grid_registry(grid_name, name)
        grid = Grid.find_by(name: grid_name)
        halt_request(404, {error: 'grid Not found'}) if !grid
        registry = grid.registries.find_by(name: name)
        halt_request(404, {error: 'Not found'}) if !registry

        unless current_user.grid_ids.include?(grid.id)
          halt_request(403, {error: 'Access denied'})
        end

        registry
      end

      # /v1/external_registries/:grid_name/:name
      r.on ':grid_name/:name' do |grid_name, name|
        registry = load_grid_registry(grid_name, name)

        # GET
        r.get do
          r.is do
            @registry = registry
            render('external_registries/show')
          end
        end

        # DELETE
        r.delete do
          r.is do
            registry.destroy
            response.status = 200
          end
        end
      end
    end
  end
end
