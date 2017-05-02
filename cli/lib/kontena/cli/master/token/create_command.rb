require_relative 'common'

module Kontena::Cli::Master::Token
  class CreateCommand < Kontena::Command

    include Common

    requires_current_master
    requires_current_master_token

    option ['-s', '--scopes'], '[SCOPES]', "Comma separated list of access scopes for the generated token", default: 'user'
    option ['-e', '--expires-in'], '[SECONDS]', "Access token expiration time. Use 0 for never.", default: '7200'
    option ['-c', '--code'], :flag, "Generate an authorization code"
    option ['-u', '--user'], '[EMAIL]', 'Generate a token for another user'
    option ['--id'], :flag, "Only output the token ID"
    option ['--token'], :flag, "Only output the access_token (or authorization code)"

    option ['--return'], :flag, "Return the response hash", hidden: true

    def execute
      params = {
        response_type: self.code? ? 'code' : 'token',
        scope: self.scopes,
        expires_in: self.expires_in
      }
      params[:user] = self.user if self.user
      data = token_data_to_hash(client.post("/oauth2/authorize", params))

      return data if self.return?

      if self.id?
        puts data[:id]
        exit 0
      end

      if self.token?
        puts data[:access_token] || data[:code]
        exit 0
      end

      data.each do |key, value|
        puts "%26.26s : %s" % [key, value]
      end
    end
  end
end
