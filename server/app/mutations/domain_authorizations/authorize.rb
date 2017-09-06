require 'acme-client'
require 'openssl'

require_relative '../grid_certificates/common'
require_relative '../../services/logging'

module GridDomainAuthorizations
  class Authorize < Mutations::Command
    include GridCertificates::Common
    include Logging

    required do
      model :grid, class: Grid
      string :domain
      string :authorization_type, in: ['dns-01', 'tls-sni-01'], default: 'dns-01'
    end

    optional do
      string :linked_service
    end

    def validate
      unless grid.grid_secrets.find_by(name: LE_PRIVATE_KEY)
        add_error(:le_registration, :missing, "Let's Encrypt registration missing")
      end
      if self.authorization_type == 'tls-sni-01'
        add_error(:linked_service, :missing, "Service link needs to be given for tls-sni-01 authorization type") unless self.linked_service
      end
      if self.linked_service
        add_error(:linked_service, :not_found, "Linked service needs to point to existing service") unless @linked_service = resolve_service(self.grid, linked_service)
      end
    end

    def execute
      authorization = acme_client(self.grid).authorize(domain: self.domain)
      challenge = nil
      case self.authorization_type
      when 'dns-01'
        debug "creating dns-01 challenge"
        challenge = authorization.dns01
        if challenge.nil?
          add_error(:challenge, :dns_01, "LE gave back empty dns-01 challenge!?!?")
          return
        end
        challenge_opts = {
          'record_name' => challenge.record_name,
          'record_type' => challenge.record_type,
          'record_content' => challenge.record_content
        }
      when 'tls-sni-01'
        debug "creating tls-sni-01 challenge"
        challenge = authorization.tls_sni01
        if challenge.nil?
          add_error(:challenge, :tls_sni_01, "LE gave back empty tls-sni-01 challenge!?!?")
          return
        end
        verification_cert = [challenge.certificate.to_pem, challenge.private_key.to_pem].join
      end

      if authz = get_authz_for_domain(self.grid, self.domain)
        authz.destroy
      end

      authz = GridDomainAuthorization.create!(
        grid: self.grid,
        domain: self.domain,
        authorization_type: self.authorization_type,
        challenge: challenge.to_h,
        challenge_opts: challenge_opts,
        tls_sni_certificate: verification_cert,
        grid_service: @linked_service)

      if self.authorization_type == 'tls-sni-01'
        # We need to deploy the linked service to get the certs in place
        outcome = GridServices::Deploy.run(grid_service: @linked_service, force: true)
        if outcome.success?
          authz.grid_service_deploy = outcome.result
          authz.save
        else
          add_error(:linked_service, :deploy, outcome.errors)
        end
      end

      authz
    rescue Acme::Client::Error::Unauthorized
      add_error(:acme_client, :unauthorized, "Registration probably missing for LE")
    end

  end
end