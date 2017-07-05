require 'timeout'

require_relative 'common'
require_relative '../../services/logging'

module GridCertificates
  class GetCertificate < Mutations::Command
    include Common
    include Logging

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

        Timeout::timeout(30) {
          info 'waiting for DNS validation...'
          sleep 1 until challenge.verify_status == 'valid'
          info 'DNS validation complete'
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
      secrets << upsert_secret("#{self.secret_name}_PRIVATE_KEY", cert_priv_key)
      secrets << upsert_secret("#{self.secret_name}_CERTIFICATE", cert)
      secrets << upsert_secret("#{self.secret_name}_BUNDLE", [cert, cert_priv_key].join)

      secrets
    rescue Timeout::Error
      warn 'timeout while waiting for DNS verfication status'
      add_error(:challenge_verify, :timeout, 'Challenge verification timeout')
    rescue Acme::Client::Error => exc
      error "#{exc.class.name}: #{exc.message}"
      error exc.backtrace.join("\n") if exc.backtrace
      add_error(:acme_client, :error, exc.message)
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
