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
      string :authorization_type, in: ['dns-01', 'http-01', 'tls-sni-01'], default: 'dns-01'
    end

    optional do
      string :linked_service
    end

    # @return [Boolean]
    def requires_linked_service?
      case authorization_type
      when 'dns-01'
        false
      when 'http-01'
        true
      when 'tls-sni-01'
        true
      end
    end

    # @return [Integer, nil]
    def requires_linked_port?
      case authorization_type
      when 'dns-01'
        nil
      when 'http-01'
        80
      when 'tls-sni-01'
        443
      end
    end

    def validate
      unless grid.grid_secrets.find_by(name: LE_PRIVATE_KEY)
        add_error(:le_registration, :missing, "Let's Encrypt registration missing")
      end
      if !requires_linked_service? && self.linked_service
        add_error(:linked_service, :invalid, "Service link cannot be given for the #{authorization_type} authorization type")
      elsif requires_linked_service? && !self.linked_service
        add_error(:linked_service, :missing, "Service link needs to be given for the #{authorization_type} authorization type")
      elsif linked_service
        @lb_service = resolve_service(self.grid, linked_service)
        if @lb_service.nil?
          add_error(:linked_service, :not_found, "Linked service not found: #{linked_service}")
        elsif (port = requires_linked_port?) && !port_open?(@lb_service, port)
          add_error(:linked_service, :invalid, "Linked service does not have port #{port} open")
        end
      end
    end

    # @param linked_service [GridService]
    # @param port [Integer]
    # @return [Boolean]
    def port_open?(linked_service, port)
      return true if linked_service.net == 'host'
      return true if linked_service.ports.any? { |p| p['node_port'] == port }

      false
    end

    def execute
      authorization = acme_client(self.grid).authorize(domain: self.domain)
      challenge = nil
      case self.authorization_type
      when 'dns-01'
        debug "creating dns-01 challenge"
        challenge = authorization.dns01
        if challenge.nil?
          add_error(:challenge, :missing, "LE did not offer any dns-01 challenge")
          return
        end
        challenge_opts = {
          'record_name' => challenge.record_name,
          'record_type' => challenge.record_type,
          'record_content' => challenge.record_content
        }
      when 'http-01'
        debug "creating http-01 challenge"
        challenge = authorization.http01
        if challenge.nil?
          add_error(:challenge, :missing, "LE did not offer any http-01 challenge")
          return
        end
        challenge_opts = {
          'token' => challenge.token,
          'content' => challenge.file_content,
        }
      when 'tls-sni-01'
        debug "creating tls-sni-01 challenge"
        challenge = authorization.tls_sni01
        if challenge.nil?
          add_error(:challenge, :missing, "LE did not offer any tls-sni-01 challenge")
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
        expires_at: authorization.expires,
        challenge: challenge.to_h,
        challenge_opts: challenge_opts,
        tls_sni_certificate: verification_cert,
        grid_service: @lb_service
      )

      if @lb_service
        # We need to deploy the linked service to get the challenge in place
        outcome = GridServices::Deploy.run(grid_service: @lb_service, force: true)
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
