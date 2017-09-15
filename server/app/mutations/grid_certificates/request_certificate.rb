require 'timeout'

require_relative 'common'
require_relative '../../services/logging'

module GridCertificates
  class RequestCertificate < Mutations::Command
    include Common
    include Logging
    include WaitHelper

    required do
      model :grid, class: Grid
      array :domains do
        string
      end
    end

    def validate
      self.domains.each do |domain|
        domain_authz = get_authz_for_domain(self.grid, domain)

        if domain_authz
          if domain_authz.authorization_type == 'dns-01'
            # Check that the expected DNS record is already in place
            unless validate_dns_record(domain, domain_authz.challenge_opts['record_content'])
              add_error(:dns_record, :invalid, "Expected DNS record not present for domain #{domain}")
            end
          end
        else
          add_error(:authorization, :not_found, "Domain authorization not found for domain #{domain}")
        end

      end
    end

    def verify_domain(domain)
      domain_authorization = get_authz_for_domain(self.grid, domain)
      challenge = le_client.challenge_from_hash(domain_authorization.challenge)
      if domain_authorization.state == :created
        info "requesting verification for domain #{domain}"
        success = challenge.request_verification
        if success
          domain_authorization.state = :requested
          domain_authorization.save
        else
          add_error(:request_verification, :failed, "Requesting verification failed")
        end
      end

      wait_until!("domain verification for #{domain} is valid", interval: 1, timeout: 30, threshold: 10) {
        challenge.verify_status != 'pending'
      }

      case challenge.verify_status
      when 'valid'
        domain_authorization.state = :validated
      when 'invalid'
        domain_authorization.state = :invalid
        add_error(:challenge, :invalid, challenge.error['detail'])
      end

      domain_authorization.save
    rescue Timeout::Error
      warn 'timeout while waiting for DNS verfication status'
      add_error(:challenge_verify, :timeout, 'Challenge verification timeout')
    rescue Acme::Client::Error => exc
      error exc
      add_error(:acme_client, :error, exc.message)
    end

    def has_errors?
      return true if @errors && @errors.size > 0
      false
    end

    def execute

      self.domains.each do |domain|
        verify_domain(domain)
      end

      # some domain verifications has failed, errors already added
      return if has_errors?

      csr = Acme::Client::CertificateRequest.new(names: self.domains)
      certificate = le_client.new_certificate(csr)

      certificate_model = self.grid.certificates.find_by(subject: self.domains[0])

      if certificate_model
        certificate_model.alt_names = self.domains[1..-1]
        certificate_model.valid_until = certificate.x509.not_after
        certificate_model.private_key = certificate.request.private_key.to_pem
        certificate_model.certificate = certificate.to_pem
        certificate_model.chain = certificate.chain_to_pem

        certificate_model.save
      else
        certificate_model = Certificate.create!(
          grid: self.grid,
          subject: self.domains[0],
          alt_names: self.domains[1..-1],
          valid_until: certificate.x509.not_after,
          private_key: certificate.request.private_key.to_pem,
          certificate: certificate.to_pem,
          chain: certificate.chain_to_pem
        )
      end

      refresh_grid_services(certificate_model)

      certificate_model

    rescue Acme::Client::Error => exc
      error exc
      add_error(:acme_client, :error, exc.message)
    end

    def le_client
      @le_client ||= acme_client(self.grid)
    end

    ##
    # @param [Certificate]
    def refresh_grid_services(certificate)
      certificate.grid.grid_services.where(:'certificates.subject' => certificate.subject).each do |grid_service|
        info "force service #{grid_service.to_path} update for updated certificate #{certificate.subject}"
        grid_service.set(updated_at: Time.now.utc)
      end
    end
  end

end

