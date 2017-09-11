
module Kontena::Cli::Certificate
  class GetCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    option '--cert-type', 'CERT_TYPE', 'The type of certificate to get: fullchain or cert', default: 'fullchain'
    parameter "DOMAIN ...", "Domain(s) to get certificate for"


    def execute
      require_api_url
      token = require_token
      data = {domains: domain_list, cert_type: cert_type}

      spinner "Requesting certificate for #{domain_list.join(',').colorize(:cyan)} " do
        response = client(token).post("grids/#{current_grid}/certificates", data)
      end

    end
  end
end
