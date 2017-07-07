require 'timeout'

require_relative 'common'
require_relative '../../services/logging'

module GridCertificates
  class GetCertificate < Mutations::Command
    include Common
    include Logging
    include WaitHelper

    LE_CERT_PREFIX = 'LE_CERTIFICATE'.freeze

    required do
      model :grid, class: Grid
      string :secret_name

      array :domains do
        string
      end
      string :cert_type, in: ['cert', 'chain', 'fullchain'], default: 'fullchain'
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

    def execute

      csr = Acme::Client::CertificateRequest.new(names: self.domains)
      client = acme_client(self.grid)

      self.domains.each do |domain|
        domain_authz = get_authz_for_domain(self.grid, domain)

        challenge = client.challenge_from_hash(domain_authz.challenge)
        if domain_authz.state == :created
          info 'requesting verification'
          success = challenge.request_verification
          if success
            domain_authz.state = :requested
            domain_authz.save
          end
        end

        wait_until!("domain verification for #{domain} is valid", interval: 1, timeout: 30, threshold: 10) {
          challenge.verify_status == 'valid'
        }

        domain_authz.state = :validated
        domain_authz.save

      end

      certificate = client.new_certificate(csr)
      cert_priv_key = certificate.request.private_key.to_pem
      cert = nil
      case self.cert_type
        when 'fullchain'
          cert = certificate.fullchain_to_pem
        when 'chain'
          cert = certificate.chain_to_pem
        when 'cert'
          cert = certificate.to_pem
      end


      secrets = []
      private_key_secret = upsert_secret("#{self.secret_name}_PRIVATE_KEY", cert_priv_key)
      cert_secret = upsert_secret("#{self.secret_name}_CERTIFICATE", cert)
      bundle_secret = upsert_secret("#{self.secret_name}_BUNDLE", [cert, cert_priv_key].join)

      cert_model = upsert_certificate(self.grid, self.domains, certificate, private_key_secret, cert_secret, bundle_secret, self.cert_type)

      cert_model
    rescue Timeout::Error
      warn 'timeout while waiting for DNS verfication status'
      add_error(:challenge_verify, :timeout, 'Challenge verification timeout')
    rescue Acme::Client::Error => exc
      error "#{exc.class.name}: #{exc.message}"
      error exc.backtrace.join("\n") if exc.backtrace
      add_error(:acme_client, :error, exc.message)
    end

    def upsert_certificate(grid, domains, certificate, private_key_secret, certificate_secret, bundle_secret, certificate_type)
      cert = self.grid.certificates.find_by(domain: domains[0])
      if cert
        cert.domain = domains[0]
        cert.alt_names = domains[1..-1]
        cert.valid_until = certificate.x509.not_after
        cert.cert_type = certificate_type
        cert.private_key = private_key_secret
        cert.certificate = certificate_secret
        cert.certificate_bundle = bundle_secret
        cert.save
      else
        cert = Certificate.create!(
          grid: grid,
          domain: domains[0],
          valid_until: certificate.x509.not_after,
          alt_names: domains[1..-1],
          cert_type: certificate_type,
          private_key: private_key_secret,
          certificate: certificate_secret,
          certificate_bundle: bundle_secret
        )
      end
      cert
    end

    def validate_dns_record(domain, expected_record)
      resolv = Resolv::DNS.new()
      info "validating domain:_acme-challenge.#{domain}"
      resource = resolv.getresource("_acme-challenge.#{domain}", Resolv::DNS::Resource::IN::TXT)
      info "got record: #{resource.strings}, expected: #{expected_record}"
      expected_record == resource.strings[0]
    rescue
      false
    end
  end
end
