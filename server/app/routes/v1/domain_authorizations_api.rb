module V1
  class DomainAuthorizationsApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers

    route do |r|

      validate_access_token
      require_current_user

      def load_domain_auth(grid_name, domain)
        grid = load_grid(grid_name) # Handles also access check to grid for current_user
        grid.grid_domain_authorizations.find_by(domain: domain)
      end

      r.on ':grid_name/:domain' do |grid_name, domain|
        r.is do
          r.get do
            @domain_authorization = load_domain_auth(grid_name, domain)
            halt_request(404, {error: "Domain authorization not found)"}) unless @domain_authorization

            render('domain_authorizations/show')
          end
        end
      end
    end
  end
end