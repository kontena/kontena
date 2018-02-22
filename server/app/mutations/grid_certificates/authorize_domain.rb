require 'acme-client'
require 'openssl'

require_relative 'common'
require_relative '../../services/logging'
#
# Deprecated
#
module GridCertificates
  class AuthorizeDomain < Mutations::Command
    include Common
    include Logging

    required do
      model :grid, class: Grid
      string :domain
    end

    def execute

      authorization = acme_client(self.grid).authorize(domain: self.domain)
      challenge = authorization.dns01
      challenge_opts = {
        'record_name' => challenge.record_name,
        'record_type' => challenge.record_type,
        'record_content' => challenge.record_content
      }
      authz = get_authz_for_domain(self.grid, self.domain)
      if authz
        authz.state = :created
        authz.update_attributes(grid: self.grid, domain: self.domain, challenge: challenge.to_h, challenge_opts: challenge_opts)
      else
        authz = GridDomainAuthorization.new(grid: self.grid, domain: self.domain, challenge: challenge.to_h, challenge_opts: challenge_opts)
      end

      authz.save
      authz
    rescue Acme::Client::Error::Unauthorized
      add_error(:acme_client, :unauthorized, "Registration probably missing for LE")
    end
  end
end
