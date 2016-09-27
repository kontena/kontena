require_relative '../../common'
require_relative 'roles/add_command'

module Kontena::Cli::Master::Users
  class InviteCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "EMAIL ...", "List of emails"

    option ['-r', '--roles'], '[ROLES]', 'Comma separated list of roles to assign to the invited users'
    option ['-c', '--code'], :flag, 'Only output the invite code'

    requires_current_master
    requires_current_master_token

    def execute
      if self.roles
        roles = self.roles.split(',')
      else
        roles = []
      end

      email_list.each do |email|
        begin
          data = { email: email, response_type: 'invite' }
          response = client.post('/oauth2/authorize', data)
          if self.code?
            puts response['invite_code']
          else
            puts "Invitation created for #{response['email']}".colorize(:green)
            puts "  * code:    #{response['invite_code']}"
            puts "  * command: kontena master join #{current_master.url} #{response['invite_code']}"
          end
          roles.each do |role|
            Kontena.run("master users role add #{role.shellescape} #{email.shellescape}")
          end
        rescue
          puts "Failed to invite #{email}".colorize(:red)
          ENV["DEBUG"] && puts("#{$!} - #{$!.message} -- #{$!.backtrace}")
        end
      end
    end
  end
end
