module Kontena::Cli::Account
  class AuthCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "[NAME]", "Account name"

    option "--password", "PASSWORD", "Account password (optional)"

    def execute

      if name.nil? && Kontena.config.current_account
        account = Kontena.config.current_account
      elsif name.nil?
        abort "Account not selected".colorize(:red)
      else
        account = Kontena.config.find_account(name)
        abort "Account not found".colorize(:red) unless account
      end

      if password.to_s.empty?
        require 'highline/import'
        password = ask("Password: ") { |q| q.echo = "*" }
      end

      client = Kontena::AccountClient.new(account)
      if client.authenticate
        Kontena.config.current_account = account['name']
        puts "Authenticated to #{name}".colorize(:green)
      else
        abort "Authentication failed".colorize(:red)
      end
    end
  end
end

