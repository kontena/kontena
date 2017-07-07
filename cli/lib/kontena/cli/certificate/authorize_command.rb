
module Kontena::Cli::Certificate
  class AuthorizeCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions


    parameter "DOMAIN", "Domain to authorize"

    option "--auth-type", "AUTH_TYPE", "Authorization type, either dns-01 or tls-sni-01", default: 'dns-01'
    option ["--lb", "--loadbalancer"], "LB", "Link to loadbalancer where the certificate will be used on"

    def execute
      require_api_url
      token = require_token
      raise "LB Link has to be given if tls-sni-01 authorization type is used" if (self.auth_type == 'tls-sni-01' && self.lb.nil?)
      data = {domain: self.domain, authorization_type: self.auth_type, lb_link: self.lb}

      response = client(token).put("domain_authorizations/#{current_grid}/#{self.domain}", data)

      puts "Authorization successfully created. Use the following details to create necessary validations:"
      if self.auth_type == 'dns-01'
        challenge_opts = response['challenge_opts']
        puts "Record name: #{challenge_opts['record_name']}.#{domain}"
        puts "Record type: #{challenge_opts['record_type']}"
        puts "Record content: #{challenge_opts['record_content']}"
      elsif self.auth_type == 'tls-sni-01'
        puts "Point the public DNS A record of #{self.domain} to the public IP address(es) of the #{self.lb}"
      end
    end
  end
end
