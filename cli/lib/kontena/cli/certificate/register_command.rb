
module Kontena::Cli::Certificate
  class RegisterCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions


    parameter "EMAIL", "Email to register"

    def execute
      require_api_url
      token = require_token

      data = {email: email}
      response = client(token).post("certificates/#{current_grid}/register", data)
      puts 'Email registered to LetsEncrypt'
    end
  end
end
