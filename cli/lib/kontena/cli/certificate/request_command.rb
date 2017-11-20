
module Kontena::Cli::Certificate
  class RequestCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "DOMAIN ...", "Domain(s) to get certificate for"

    def execute
      require_api_url
      token = require_token
      data = {domains: domain_list}

      spinner "Requesting certificate for #{domain_list.join(',').colorize(:cyan)} " do
        response = client(token).post("grids/#{current_grid}/certificates", data)
      end

    end
  end
end
