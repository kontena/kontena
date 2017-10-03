class CertificateRenewJob
  include Celluloid
  include Logging
  include CurrentLeader
  include WaitHelper
  include DistributedLocks

  RENEW_INTERVAL = 1.hour.to_i

  RENEW_TRESHOLD = 7.days

  def initialize(perform = true)
    async.perform if perform
  end

  def perform
    # sleep a while first to allow everything to settle down before running this loop
    sleep 5.minutes
    info 'starting to watch certificate renewals'
    loop do
      if leader?
        with_dlock('cert_renewal_job') {
          renew_certificates
        }
      end
      sleep RENEW_INTERVAL
    end
  end

  def renew_certificates
    Certificate.where(:valid_until.lt => Time.now + RENEW_TRESHOLD).each do |cert|
      renew_certificate(cert)
    end
  end

  def renew_certificate(certificate)
    if certificate.auto_renewable?
      info "certificate renewal needed for #{certificate.subject}"
      authorize_domains(certificate)
      request_new_cert(certificate)
    end
  rescue => exc
      error "Failed to renew certificate for #{certificate.subject}"
      error exc
  end

  # Creates new authorizations for all the domains
  def authorize_domains(certificate)
    certificate.all_domains.each do |domain|
      info "re-authorizing domain #{domain}"
      domain_auth = certificate.grid.grid_domain_authorizations.find_by(domain: domain)
      outcome = GridDomainAuthorizations::Authorize.run(
        grid: certificate.grid,
        domain: domain,
        authorization_type: 'tls-sni-01',
        linked_service: "#{domain_auth.grid_service.stack.name}/#{domain_auth.grid_service.name}"
      )
      if outcome.success?
        domain_auth = outcome.result
        wait_until!("deployment of tls-sni secret is finished", timeout: 300, threshold: 20) {
          domain_auth.reload.status != :deploying
        }
        raise "Deployment of tls-sni secret failed" if domain_auth.reload.status == :deploy_error
      else
        # No point to continue, cert renewal not gonna succeed
        raise "Domain authorization failed: #{outcome.errors.message}"
      end
    end
  end

  def request_new_cert(certificate)
    info "requesting certificate for #{certificate.subject}"
    outcome = GridCertificates::RequestCertificate.run(grid: certificate.grid, domains: certificate.all_domains)
    unless outcome.success?
      raise "Certificate request failed: #{outcome.errors.message}"
    end
    info "certificate for #{certificate.subject} renewed succesfully"
  end
end