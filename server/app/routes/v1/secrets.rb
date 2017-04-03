module V1
  class SecretsApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers
    include Auditor

    route do |r|

      validate_access_token
      require_current_user

      unless SymmetricEncryption.cipher?
        halt_request(503, {error: 'Vault not configured'})
      end


      # @param [Grid] grid
      # @param [String] secret_name
      # @return [GridSecret]
      def load_grid_secret(grid, secret_name)
        grid_secret = grid.grid_secrets.find_by(name: secret_name)
        halt_request(404, {error: 'Not found'}) if !grid_secret

        grid_secret
      end

      # @param [Hash] data
      def create_secret(data)
        data[:grid] = @grid
        outcome = GridSecrets::Create.run(data)

        if outcome.success?
          @grid_secret = outcome.result
          audit_event(request, @grid, @grid_secret, 'create', nil, [:body])
          response.status = 201
          render('grid_secrets/show')
        else
          response.status = 422
          {error: outcome.errors.message}
        end
      end

      # @param [GridSecret] secret
      # @param [String] value
      def update_secret(secret, value)
        outcome = GridSecrets::Update.run(
          grid_secret: secret,
          value: value
        )

        if outcome.success?
          @grid_secret = outcome.result
          audit_event(request, @grid, @grid_secret, 'update', nil, [:body])
          response.status = 200
          render('grid_secrets/show')
        else
          response.status = 422
          {error: outcome.errors.message}
        end
      end

      # /v1/secrets/:grid_name/:secret_name
      r.on ':grid_name/:secret_name' do |grid_name, secret_name|

        @grid = load_grid(grid_name)

        r.put do
          # PUT /v1/secrets/:grid_name/:secret_name
          r.is do
            secret = @grid.grid_secrets.find_by(name: secret_name)
            data = parse_json_body

            if secret
              update_secret(secret, data['value'])
            elsif data['upsert']
              create_secret(data)
            else
              response.status = 404
            end
          end
        end

        @grid_secret = load_grid_secret(@grid, secret_name)

        # GET /v1/secrets/:grid_name/:secret_name
        r.get do
          r.is do
            audit_event(r, @grid_secret.grid, @grid_secret, 'show')
            render('grid_secrets/show')
          end
        end

        # DELETE /v1/secrets/:grid_name/:secret_name
        r.delete do
          r.is do
            @grid_secret.destroy
            audit_event(r, @grid_secret.grid, @grid_secret, 'delete')
            {}
          end
        end
      end
    end
  end
end
