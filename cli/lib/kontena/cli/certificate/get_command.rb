
module Kontena::Cli::Certificate
  class GetCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions


    option '--secret-name', 'SECRET_NAME', 'The name for the secret to store the certificate in'
    option '--cert-type', 'CERT_TYPE', 'The type of certificate to get: fullchain, chain or cert', default: 'fullchain'
    parameter "DOMAIN ...", "Domain(s) to get certificate for"


    def execute
      require_api_url
      token = require_token
      secret = secret_name || "LE_CERTIFICATE_#{domain_list[0].gsub('.', '_')}"
      data = {
        domains: domain_list,
        secret_name: secret,
        cert_type: self.cert_type
      }
      response = client(token).post("grids/#{current_grid}/certificates", data)
      puts "Certificate successfully received and stored into vault with keys:"
      puts response['private_key_secret'].colorize(:green)
      puts response['certificate_secret'].colorize(:green)
      puts response['certificate_bundle_secret'].colorize(:green)

      puts "\n Certificate is valid until: #{response['valid_until']}"
      puts "Use the #{secret}_BUNDLE with Kontena loadbalancer!"
    end
  end
end
