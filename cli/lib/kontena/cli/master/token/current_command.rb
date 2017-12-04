require_relative 'common'

module Kontena::Cli::Master::Token
  class CurrentCommand < Kontena::Command

    include Kontena::Cli::Common
    include Common

    requires_current_master
    requires_current_master_token

    option '--token', :flag, "Only output access token"
    option '--refresh-token', :flag, "Only output refresh token"
    option '--expires-in', :flag, "Only output expires in seconds"
    option '--id', :flag, "Only output access token id"

    def execute
      if self.token?
        puts current_master.token.access_token
        return
      end

      if self.refresh_token?
        if current_master.token.refresh_token
          puts current_master.token.refresh_token
        end
        return
      end

      if self.expires_in?
        if current_master.token.expires_at.to_i > 0
          puts Time.now.utc.to_i - current_master.token.expires_at
        end
        return
      end

      if self.id?
        Kontena.run!(['master', 'token', 'show',  '--id', current_master.token.access_token])
      else
        Kontena.run!(['master', 'token', 'show',  current_master.token.access_token])
      end
    end
  end
end

