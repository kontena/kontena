module V1
  class DomainAuthApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers
    include Auditor

    route do |r|
      validate_access_token
      require_current_user

      # /v1/domain_authorizations/:grid/
      r.on ':grid' do |grid|
        load_grid(grid)
        r.is do
          r.get do
            @authorizations = @grid.grid_domain_authorizations
            response.status = 200
            render('domain_authorizations/index')
          end
        end
        r.on ':domain' do |domain|
          r.put do
            data = parse_json_body
            data[:grid] = @grid
            outcome = GridCertificates::AuthorizeDomain.run(data)
            if outcome.success?
              @authorization = outcome.result
              response.status = 200
              render('domain_authorizations/show')
            else
              response.status = 422
              {error: outcome.errors.message}
            end
          end
          r.get do
            @authorization = @grid.grid_domain_authorizations.find_by(domain: domain)
            if @authorization
              response.status = 200
              render('domain_authorizations/show')
            else
              response.status = 404
              {error: "Not found"}
            end
          end
        end
      end
    end
  end
end
