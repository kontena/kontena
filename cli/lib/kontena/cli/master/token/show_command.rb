require_relative 'common'

module Kontena::Cli::Master::Token
  class ShowCommand < Kontena::Command

    parameter "TOKEN_OR_ID", "Access token or access token id"

    include Kontena::Cli::Common
    include Common

    requires_current_master
    requires_current_master_token

    option '--id', :flag, "Only output access token id", hidden: true

    def execute
      data = client.get("/oauth2/tokens/#{token_or_id}")
      output = token_data_to_hash(data)

      if id?
        puts output[:id]
        return
      end

      id = output.delete(:id)
      puts '%s:' % id
      output.each do |key, value|
        puts "  %s: %s" % [key, value.nil? ? '-' : value]
      end
    end
  end
end


