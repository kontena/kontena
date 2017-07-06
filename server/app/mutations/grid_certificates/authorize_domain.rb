require 'acme-client'
require 'openssl'

require_relative 'common'
require_relative '../../services/logging'

module GridCertificates
  class AuthorizeDomain < Mutations::Command
    include Common
    include Logging

    LE_TLS_SNI_PREFIX = 'LE_TLS_SNI'.freeze

    required do
      model :grid, class: Grid
      string :domain
      string :authorization_type, in: ['dns-01', 'tls-sni-01'], default: 'dns-01'
    end

    optional do
      string :lb_link
    end

    def validate
      if self.authorization_type == 'tls-sni-01'
        add_error(:lb_link, :missing, "LB link needs to be given for tls-sni-01 authorization type") unless self.lb_link
      end
      if self.lb_link
        @lb_service = resolve_service(self.grid, lb_link)
        add_error(:lb_link, :not_found, "LB link needs to point to existing service") unless @lb_service
      end
    end

    def execute
      authorization = acme_client(self.grid).authorize(domain: self.domain)
      challenge = nil
      case self.authorization_type
      when 'dns-01'
        debug "creating dns-01 challenge"
        challenge = authorization.dns01
        challenge_opts = {
          'record_name' => challenge.record_name,
          'record_type' => challenge.record_type,
          'record_content' => challenge.record_content
        }
      when 'tls-sni-01'
        debug "creating tls-sni-01 challenge"
        challenge = authorize_tls_sni(authorization)
        return unless challenge
      end

      if authz = get_authz_for_domain(self.grid, self.domain)
        authz.state = :created
        authz.update_attributes(grid: self.grid, domain: self.domain, authorization_type: self.authorization_type, challenge: challenge.to_h, challenge_opts: challenge_opts)
      else
        authz = GridDomainAuthorization.new(grid: self.grid, domain: self.domain, authorization_type: self.authorization_type, challenge: challenge.to_h, challenge_opts: challenge_opts)
      end

      authz.save
      authz
    rescue Acme::Client::Error::Unauthorized
      add_error(:acme_client, :unauthorized, "Registration probably missing for LE")
    end

    def authorize_tls_sni(authorization)
      challenge = authorization.tls_sni01
      verification_cert = [challenge.certificate.to_pem, challenge.private_key.to_pem].join
      secret_name = [LE_TLS_SNI_PREFIX, domain_to_vault_key(self.domain)].join('_')
      puts "************** #{secret_name}"
      tls_sni_secret = upsert_secret(secret_name, verification_cert)
      if tls_sni_secret.nil?
        add_error(:tls_sni_secret, :error, "Failed to store the needed tls-sni-01 secret")
        return
      end
      debug "upserted tls-sni secret: #{tls_sni_secret.name}"
      add_secret_to_service(tls_sni_secret, @lb_service) if @lb_service
      challenge
    end

    def add_secret_to_service(secret, grid_service)
      unless grid_service.secrets.index {|s| s['secret'] == secret.name}
        info "adding tls-sni secret to service: #{grid_service.qualified_name}"
        secrets = grid_service.secrets.map{ |s| {'secret' => s['secret'], 'name' => s['name'], 'type' => s['type']}}
        secrets << {secret: secret.name, name: 'SSL_CERTS', type: 'env'}
        outcome = GridServices::Update.run(grid_service: grid_service, secrets: secrets)
        unless outcome.success?
          add_error(:tls_sni_secret, :error, outcome.errors.message)
        end
      else
        info "no need to add tls-sni secret, it already exists on service #{grid_service.qualified_name}"
      end
    end

  end
end
