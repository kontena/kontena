require_relative '../services/logging'

class CertificateRenewJob
  include Celluloid
  include Logging
  include CurrentLeader
  include Workers

  CHECK_INTERVAL = 30 * 60 # 30min interval to check certs

  def initialize(autostart = true)
    async.perform
  end

  def perform
    info 'starting to watch certificates'
    every(CHECK_INTERVAL) do
      if leader?
        check_certificates
      end
    end
  end

  def check_certificates
    Certificate.all.each do |cert|
      begin
        next unless should_renew?(cert) && can_renew?(cert)
        start_time = Time.now
        authz = authorize_domain(cert.grid, cert.domain)
        # Need to authorize all alt domains as well
        cert.alt_names.each do |domain|
          authorize_domain(cert.grid, domain)
        end
        # Wait for LB to update
        # TODO How to know when LB has been updated
        sleep(60)

        get_new_cert(cert)
      rescue => exc
        error "certificate renewal for #{cert.domain} failed: #{exc.message}"
      end
    end
  end

  def should_renew?(cert)
    (Time.now + 7.days) > cert.valid_until
  end

  def can_renew?(cert)
    domain_auth = cert.grid.grid_domain_authorizations.find_by(domain: cert.domain)
    domain_auth && domain_auth.authorization_type == 'tls-sni-01' # Only TLS_SNI auth can be renewed automatically
  end

  def authorize_domain(grid, domain)
    outcome = GridCertificates::AuthorizeDomain.run(grid: grid, domain: domain)
    raise outcome.errors.message unless outcome.success?
    outcome.result
  end

  def get_new_cert(cert)
    outcome = GridCertificates::GetCertificate.run(grid: grid, domains: [cert.domain] + cert.alt_names, secret_name: cert.secret_prefix, cert_type: cert.cert_type)
    raise outcome.errors.message unless outcome.success?
  end

  def wait_for_authz_to_propagate(start_time, grid, domain)
    secret = grid.grid_secrets.find_by!(name: [GridCertificates::AuthorizeDomain::LE_TLS_SNI_PREFIX, self.domain.gsub('.', '_')].join('_'))
    lb = secret.linked_services.find(&:load_balancer?)
    wait_until!("loadbalancer #{lb.to_path} has been updated", interval: 5, timeout: 300, threshold: 60) {
      # Check all instances have been updated
      lb.grid_service_instances.all?{|i| Time.parse(i.rev) > start_time }
    }
  end

end