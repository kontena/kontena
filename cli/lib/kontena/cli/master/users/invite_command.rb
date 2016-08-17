require_relative '../../common'

module Kontena::Cli::Master::Users
  class InviteCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "EMAIL ...", "List of emails"

    def execute
      require_api_url
      token = require_token
      email_list.each do |email|
        begin
          data = { email: email, response_type: 'invite' }
          response = client(token).post('/oauth2/authorize', data)
          puts "Invitation created for #{response['email']}".colorize(:green)
          puts "  * code:  #{response['invite_code']}"
          puts "  * link:  #{response['invite_link']}"
        rescue
          puts "Failed to invite #{email}".colorize(:red)
          ENV["DEBUG"] && puts("#{$!} - #{$!.message} -- #{$!.backtrace}")
        end
      end
    end
  end
end
