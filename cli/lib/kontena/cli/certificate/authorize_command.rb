
module Kontena::Cli::Certificate
  class AuthorizeCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions


    parameter "DOMAIN", "Domain to authorize"

    option "--auth-type", "AUTH_TYPE", "Authorization type, either dns-01 or tls-sni-01", default: 'dns-01'

    def execute
      require_api_url
      token = require_token

      data = {domain: self.domain, authorization_type: self.auth_type}

      response = client(token).put("domain_authorizations/#{current_grid}/#{self.domain}", data)

      puts "Authorization successfully created. Use the following details to create necessary validations:"
      if self.auth_type == 'dns-01'
        challenge_opts = response['challenge_opts']
        puts "Record name: #{challenge_opts['record_name']}.#{domain}"
        puts "Record type: #{challenge_opts['record_type']}"
        puts "Record content: #{challenge_opts['record_content']}"
      elsif self.auth_type == 'tls-sni-01'
        puts "Point the public DNS record of #{self.domain} to the public IP address(es) of the loadbalancer used"
        puts "Link #{['LE_TLS_SNI_', self.domain.gsub('.', '_')].join('_')} secret to the loadbalancer used."
      end
    end
  end
end
