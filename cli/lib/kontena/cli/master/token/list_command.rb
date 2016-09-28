require_relative 'common'

module Kontena::Cli::Master::Token
  class ListCommand < Kontena::Command

    include Kontena::Cli::Common
    include Common

    requires_current_master
    requires_current_master_token

    def execute
      rows = []
      puts "%-26s %-18s %-11s %-10s %-20s" % ["ID", "TOKEN_TYPE", "TOKEN_LAST4", "EXPIRES_IN", "SCOPES"]
      client.get("/oauth2/tokens")["tokens"].each do |row_data|
        data = token_data_to_hash(row_data)
        puts "%-26s %-18s %-11s %-10s %-20s" % [
          data[:id],
          data[:token_type],
          data[:access_token_last_four],
          data[:expires_in],
          data[:scopes]
        ]
      end
    end
  end
end

