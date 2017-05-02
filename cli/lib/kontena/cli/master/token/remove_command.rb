module Kontena::Cli::Master::Token
  class RemoveCommand < Kontena::Command

    parameter "TOKEN_OR_ID", "Access token or access token id"

    option ['-f', '--force'], :flag, "Don't ask questions"

    requires_current_master
    requires_current_master_token

    def execute
      confirm
      client.delete("/oauth2/tokens/#{token_or_id}")
    end
  end
end

