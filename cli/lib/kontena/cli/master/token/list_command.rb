require_relative 'common'

module Kontena::Cli::Master::Token
  class ListCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::Common
    include Kontena::Cli::TableGenerator::Helper
    include Common

    requires_current_master
    requires_current_master_token

    def fields
      return ['id'] if quiet?
      { id: 'id', token_type: 'token_type', token_last4: 'access_token_last_four', expires_in: 'expires_in', scopes: 'scopes' }
    end

    def execute
      data = Array(client.get("/oauth2/tokens")["tokens"])
      print_table(data) do |row|
        next if quiet?
        row['expires_in'] = colorize(row['expires_in'].to_i)
        row['token_type'] ||= row['grant_type']
      end
    end

    def colorize(expires_in)
      return expires_in.to_s unless $stdout.tty?
      if expires_in.zero?
        pastel.yellow('never')
      elsif expires_in < 0
        pastel.red(time_ago(Time.now.to_i + expires_in))
      else
        pastel.green(time_until(expires_in))
      end
    end
  end
end

