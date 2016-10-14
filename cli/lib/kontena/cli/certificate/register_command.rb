
module Kontena::Cli::Certificate
  class RegisterCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "EMAIL", "Email to register"

    requires_current_master_token

    def execute
      data = {email: email}
      response = client.post("certificates/#{current_grid}/register", data)
      puts 'Email registered to LetsEncrypt'
    end
  end
end
