require_relative 'common'

module Kontena::Cli::Master::Token
  class CurrentCommand < Kontena::Command

    include Common

    requires_current_master
    requires_current_master_token

    option '--token', :flag, "Only output access token"
    option '--refresh-token', :flag, "Only output refresh token"
    option '--expires-in', :flag, "Only output expires in seconds"

    def execute
      if self.token?
        puts current_master.token.access_token
        exit 0
      end

      if self.refresh_token?
        if current_master.token.refresh_token
          puts current_master.token.refresh_token
        end
        exit 0
      end

      if self.expires_in?
        if current_master.token.expires_at.to_i > 0
          puts Time.now.utc.to_i - current_master.token.expires_at
        end
        exit 0
      end

      Kontena.run!(['master', 'token', 'show',  current_master.token.access_token])
    end
  end
end

