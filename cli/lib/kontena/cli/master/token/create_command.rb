require_relative 'common'

module Kontena::Cli::Master::Token
  class CreateCommand < Kontena::Command

    include Kontena::Cli::Common
    include Common

    requires_current_master
    requires_current_master_token

    option ['-s', '--scopes'], '[SCOPES]', "Comma separated list of access scopes for the generated token", default: 'user'
    option ['-e', '--expires-in'], '[SECONDS]', "Access token expiration time. Use 0 for never.", default: '7200'
    option ['-c', '--code'], :flag, "Generate an authorization code"
    option ['--id'], :flag, "Only output the token ID"
    option ['--token'], :flag, "Only output the access_token (or authorization code)"

    def execute
      params = {
        response_type: self.code? ? 'code' : 'token',
        scope: self.scopes,
        expires_in: self.expires_in
      }
      data = token_data_to_hash(client.post("/oauth2/authorize", params))

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
