
module Kontena::Cli::Certificate
  class RegisterCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions


    parameter "EMAIL", "Email to register"

    def execute
      require_api_url
      token = require_token

      data = {email: email}
      puts "By registering, you agree on Let's Encrypt Terms of Service: https://letsencrypt.org/documents/LE-SA-v1.1.1-August-1-2016.pdf"
      agree_tos = prompt.yes?("Continue?")
      if agree_tos
        response = client(token).post("certificates/#{current_grid}/register", data)
        puts 'Email registered to LetsEncrypt'
      else
        puts "Registration canceled!".colorize(:red)
      end
    end
  end
end
