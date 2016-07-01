
module Kontena::Cli::Certificate
  class AuthorizeCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions


    parameter "DOMAIN", "Domain to authorize"

    def execute
      require_api_url
      token = require_token

      data = {domain: domain}
      response = client(token).post("certificates/#{current_grid}/authorize", data)
      puts "Authorization successfully created. Use the following details to create necessary validations:"
      puts "Record name:#{response['record_name']}"
      puts "Record type:#{response['record_type']}"
      puts "Record content:#{response['record_content']}"

    end
  end
end
