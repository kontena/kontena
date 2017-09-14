class CertificateRenewJob
  include Celluloid
  include Logging
  include CurrentLeader
  include WaitHelper

  RENEW_INTERVAL = 5 * 60 # Run the renew check every 5 mins

  def initialize(perform = true)
    async.perform if perform
  end

  def perform
    # TODO Maybe sleep a while first to allow everything else to start up before running this loop?
    info 'starting to watch certificate renewals'
    every(RENEW_INTERVAL) do
      if leader?
        renew_certificates
      end
    end
  end

  def renew_certificates
    Grid.each do |grid|
      grid.certificates.each do |cert|
        renew_certificate(cert)
      end
    end
  end

  def renew_certificate(certificate)
    if should_renew?(certificate) && can_renew?(certificate)
      info "certificate renewal needed for #{certificate.subject}"
      begin
        authorize_domains(certificate)
        request_new_cert(certificate)
      rescue => exc
        error "Failed to renew certificate for #{certificate.subject}"
        error exc
      end
    end
  end

  def should_renew?(certificate)
    certificate.valid_until < (Time.now + 7.days)
  end

  # Checks if all domains are authorized with tls-sni, we can't automate anything else for now
  def can_renew?(certificate)
    certificate.all_domains.each do |domain|
      domain_auth = certificate.grid.grid_domain_authorizations.find_by(domain: domain)
      unless domain_auth && domain_auth.authorization_type == 'tls-sni-01'
        return false
      end
    end

    true
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