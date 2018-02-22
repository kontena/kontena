require_relative '../../common'
require_relative 'role/add_command'

module Kontena::Cli::Master::User
  class InviteCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "EMAIL ...", "List of emails"

    option ['-r', '--roles'], '[ROLES]', 'Comma separated list of roles to assign to the invited users'
    option ['-c', '--code'], :flag, 'Only output the invite code'
    option '--external-id', '[EXTERNAL ID]', 'Assign external id to user', hidden: true
    option '--return', :flag, 'Return the code', hidden: true

    requires_current_master
    requires_current_master_token

    def execute
      if self.roles
        roles = self.roles.split(',')
      else
        roles = []
      end
      external_id = nil
      if email_list.size == 1 && self.external_id
        external_id = self.external_id
      end
      email_list.each do |email|
        begin
          data = { email: email, external_id: external_id, response_type: 'invite' }
          response = client.post('/oauth2/authorize', data)
          if self.code?
            puts response['invite_code']
          elsif self.return?
            return response
          else
            puts pastel.green("Invitation created for #{response['email']}")
            puts "  * code:    #{response['invite_code']}"
            puts "  * command: kontena master join #{current_master.url} #{response['invite_code']}"
          end
          roles.each do |role|
            raise "Failed to add role" unless Kontena.run(["master", "user", "role", "add", role, email])
          end
        rescue => ex
          logger.error(ex)
          exit_with_error "Failed to invite #{email} : #{ex.message}"
        end
      end
    end
  end
end
