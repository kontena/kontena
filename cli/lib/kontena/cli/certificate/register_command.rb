
module Kontena::Cli::Certificate
  class RegisterCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions


    parameter "EMAIL", "Email to register"

    option '--agree-tos', :flag, "Automatically agree on Let's Encrypt Terms of Service"

    def execute
      require_api_url
      token = require_token

      data = {email: email}

      if self.agree_tos? || ask_continue
        response = client(token).post("certificates/#{current_grid}/register", data)
        puts 'Email registered to LetsEncrypt'
      end
    end

    def ask_continue
      puts "By registering, you agree on Let's Encrypt Terms of Service: https://letsencrypt.org/documents/LE-SA-v1.1.1-August-1-2016.pdf"
      exit_with_error "Registration canceled!" unless prompt.yes?("Continue?")
      true
    end
  end
end
