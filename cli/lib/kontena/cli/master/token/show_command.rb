require_relative 'common'

module Kontena::Cli::Master::Token
  class ShowCommand < Kontena::Command

    parameter "TOKEN_OR_ID", "Access token or access token id", completion: "MASTER_TOKEN"

    include Kontena::Cli::Common
    include Common

    requires_current_master
    requires_current_master_token

    def execute
      data = client.get("/oauth2/tokens/#{token_or_id}")
      output = token_data_to_hash(data)
      output.each do |key, value|
        puts "%26.26s : %s" % [key, value]
      end
    end
  end
end


