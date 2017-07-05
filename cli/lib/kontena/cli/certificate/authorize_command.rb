
module Kontena::Cli::Certificate
  class AuthorizeCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions


    parameter "DOMAIN", "Domain to authorize"

    option "--auth-type", "AUTH_TYPE", "Authorization type, either dns-01 or tls-sni-01", default: 'dns-01'
    option "--lb-link", "LB_LINK", "Link to loadbalancer where the certificate will be used on"

    def execute
      require_api_url
      token = require_token

      data = {domain: self.domain, authorization_type: self.auth_type, lb_link: self.lb_link}
      response = client(token).post("certificates/#{current_grid}/authorize", data)
      puts "Authorization successfully created. Use the following details to create necessary validations:"
      if self.auth_type == 'dns-01'
        puts "Record name: #{response['record_name']}.#{domain}"
        puts "Record type: #{response['record_type']}"
        puts "Record content: #{response['record_content']}"
      elsif self.auth_type == 'tls-sni-01'
        puts "Point the public DNS A record of #{self.domain} to the public IP address(es) of the #{self.lb_link}"
      end
    end
  end
end
