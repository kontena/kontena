module V1
  class CertificatesApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers
    include Auditor

    plugin :multi_route

    route do |r|
      validate_access_token
      require_current_user

      def authorize_domain(data)
        data[:grid] = @grid
        outcome = GridCertificates::AuthorizeDomain.run(data)
        if outcome.success?
          @authorization = outcome.result
          response.status = 201
          {
            'record_name' => @authorization.challenge_opts['record_name'],
            'record_type' => @authorization.challenge_opts['record_type'],
            'record_content' => @authorization.challenge_opts['record_content']
          }

        else
          response.status = 422
          {error: outcome.errors.message}
        end
      end

      def get_certificate(data)
        data[:grid] = @grid
        outcome = GridCertificates::GetCertificate.run(data)
        if outcome.success?
          @cert_secrets = outcome.result
          response.status = 201

          @cert_secrets.collect { |s| s.name}
        else
          response.status = 422
          {error: outcome.errors.message}
        end
      end

      def register(data)
        data[:grid] = @grid
        outcome = GridCertificates::Register.run(data)
        if outcome.success?
          response.status = 201
          {}
        else
          response.status = 422
          {error: outcome.errors.message}
        end
      end

      # /v1/certificates/:grid/
      r.on ':grid' do |grid|

        load_grid(grid)

        r.get do
          r.on ':subject' do |subject|
            @certificate = @grid.certificates.find_by(subject: subject)
            if @certificate
              response.status = 200
              render('certificates/show')
            else
              response.status = 404
              {error: 'Not found'}
            end
          end
        end

        r.delete do
          r.on ':subject' do |subject|
            @certificate = @grid.certificates.find_by(subject: subject)
            if @certificate
              outcome = GridCertificates::RemoveCertificate.run(certificate: @certificate)
              if outcome.success?
                response.status = 200
                {}
              else
                response.status = 422
                {error: outcome.errors.message}
              end
            else
              response.status = 404
              {error: 'Not found'}
            end
          end
        end

        r.post do
          # DEPRECATED
          r.on 'authorize' do
            data = parse_json_body
            authorize_domain(data)
          end
          # DEPRECATED
          r.on 'certificate' do
            data = parse_json_body
            get_certificate(data)
          end

          r.on 'register' do
            data = parse_json_body
            register(data)
          end
        end
      end

    end
  end
end
