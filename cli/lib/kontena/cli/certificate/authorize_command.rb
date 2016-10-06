
module Kontena::Cli::Certificate
  class AuthorizeCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions


    parameter "DOMAIN", "Domain to authorize"

    requires_current_master_token

    def execute

      data = {domain: domain}
      response = client.post("certificates/#{current_grid}/authorize", data)
      puts "Authorization successfully created. Use the following details to create necessary validations:"
      puts "Record name: #{response['record_name']}.#{domain}"
      puts "Record type: #{response['record_type']}"
      puts "Record content: #{response['record_content']}"
    end
  end
end
