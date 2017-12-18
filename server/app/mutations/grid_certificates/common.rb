require 'openssl'
require 'acme-client'

require_relative '../../services/logging'
require_relative '../grid_services/helpers'

module GridCertificates
  module Common
    include GridServices::Helpers
    include Logging

    LE_PRIVATE_KEY = 'LE_PRIVATE_KEY'.freeze

    ACME_ENDPOINT = 'https://acme-v01.api.letsencrypt.org/'.freeze

    def acme_client(grid)
      client = Acme::Client.new(private_key: acme_private_key(grid),
                                endpoint: acme_endpoint,
                                connection_options: { request: { open_timeout: 5, timeout: 5 } })
      client
    end

    def acme_private_key(grid)
      le_secret = grid.grid_secrets.where(name: LE_PRIVATE_KEY).first
      if le_secret.nil?
        info 'LE private key does not yet exist, creating...'
        private_key = OpenSSL::PKey::RSA.new(4096)
        outcome = GridSecrets::Create.run(grid: grid, name: LE_PRIVATE_KEY, value: private_key.to_pem)
        unless outcome.success?
          return nil # TODO Or raise something?
        end
      else
        private_key = OpenSSL::PKey::RSA.new(le_secret.value)
      end

      private_key
    end

    def domain_to_vault_key(domain)
      domain.sub('.', '_')
    end

    def get_authz_for_domain(grid, domain)
      grid.grid_domain_authorizations.find_by(domain: domain)
    end

    def acme_endpoint
      ENV['ACME_ENDPOINT'] || ACME_ENDPOINT
    end

    def resolve_service(grid, service_name)
      stack_name, service = service_name.split('/')
      stack = grid.stacks.find_by(name: stack_name)
      return nil if stack.nil?

      stack.grid_services.find_by(name: service)
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

    # @param domain [String] externally resolveable address
    # @param hostname [String] *.acme.invalid
    def validate_tls_sni(domain, hostname)
      info "validating tls-sni-01 challenge at #{domain}:443..."

      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.set_params(verify_mode: OpenSSL::SSL::VERIFY_NONE, verify_hostname: false)

      tcp_socket = Socket.tcp(domain, 443)

      ssl_socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_context)
      ssl_socket.hostname = hostname # tls-sni
      ssl_socket.connect

      ssl_cert = ssl_socket.peer_cert

      debug "got tls peer cert for #{domain}:443: #{ssl_cert.subject}"

      ssl_cert.extensions.each do |ext|
        next if ext.oid != 'subjectAltName'

        ext.value.split(',').each{|name|
          name = name.strip
          next unless name.start_with? 'DNS:'
          next unless name[4..-1] == hostname

          info "got tls-sni-01 challenge cert with subjectAltName: #{ext.value}"

          return true
        }
      end

      add_error(:domains, :tls_sni_challenge, "Server at #{domain}:443 did not return challenge cert for #{hostname}")
      return false

    rescue OpenSSL::OpenSSLError => exc
      add_error(:domains, :tns_sni_challenge, "Failed to pre-validate tls-sni-01 challenge cert at #{domain}:443: #{exc.class}: #{exc.message}")
      return false

    rescue => exc
      error exc
      add_error(:domains, :tns_sni_challenge, "Failed to pre-validate tls-sni-01 challenge cert at #{domain}:443: #{exc.class}: #{exc.message}")
      return false
    end

    def upsert_certificate(certificate)
      if existing = Certificate.find_by(grid: grid, subject: certificate.subject)
        existing.alt_names = certificate.alt_names
        existing.valid_until = certificate.valid_until
        existing.private_key = certificate.private_key
        existing.certificate = certificate.certificate
        existing.chain = certificate.chain
        existing.save

        certificate = existing
      else
        certificate.save
      end

      refresh_certificate_services(certificate)

      return certificate
    end

    ##
    # @param [Certificate]
    def refresh_certificate_services(certificate)
      certificate.grid.grid_services.where(:'certificates.subject' => certificate.subject).each do |grid_service|
        info "force service #{grid_service.to_path} update for updated certificate #{certificate.subject}"
        update_grid_service(grid_service, force: true)
      end
    end
  end
end
