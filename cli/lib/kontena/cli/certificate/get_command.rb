
module Kontena::Cli::Certificate
  class GetCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    BANNER = "This command is now deprecated in favor of 'kontena certificate request' command".colorize(:red)

    banner BANNER

    option '--secret-name', 'SECRET_NAME', 'The name for the secret to store the certificate in'
    option '--cert-type', 'CERT_TYPE', 'The type of certificate to get: fullchain, chain or cert', default: 'fullchain'
    parameter "DOMAIN ...", "Domain(s) to get certificate for"


    def execute
      puts BANNER

      require_api_url
      token = require_token
      secret = secret_name || "LE_CERTIFICATE_#{domain_list[0].gsub('.', '_')}"
      data = {domains: domain_list, secret_name: secret}

      response = client(token).post("certificates/#{current_grid}/certificate", data)
      puts "Certificate successfully received and stored into vault with keys:"
      response.each do |secret|
        puts secret.colorize(:green)
      end
      puts "Use the #{secret}_BUNDLE with Kontena loadbalancer!"

    end
  end
end
