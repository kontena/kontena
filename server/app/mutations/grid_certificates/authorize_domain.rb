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


    def validate
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

    # Creates the self-signed cert from authorization object, puts that in vault and attaches it to the given service
    # @return [Acme::Client::Resources::Challenges::DNS01, Acme::Client::Resources::Challenges::TLSSNI01] the actual challenge
    def authorize_tls_sni(authorization)
      challenge = authorization.tls_sni01
      verification_cert = [challenge.certificate.to_pem, challenge.private_key.to_pem].join
      secret_name = [LE_TLS_SNI_PREFIX, domain_to_vault_key(self.domain)].join('_')
      tls_sni_secret = upsert_secret(secret_name, verification_cert)
      if tls_sni_secret.nil?
        add_error(:tls_sni_secret, :error, "Failed to store the needed tls-sni-01 secret")
        return
      end
      debug "upserted tls-sni secret: #{tls_sni_secret.name}"
      challenge
    end

  end
end
