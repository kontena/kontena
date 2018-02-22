require_relative '../../common'

module Kontena::Cli::Master::User
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::TableGenerator::Helper

    requires_current_master
    requires_current_master_token

    def fields
      quiet? ? ['id'] : { email: 'email', roles: 'role_list' }
    end

    def execute
      response = spin_if(!quiet? && $stdout.tty?, "Retrieving user list from Kontena Master") do
        client.get('users')['users']
      end

      print_table(response) do |row|
        if row['roles'].empty?
          row['role_list'] = ''
        else
          row['role_list'] = row['roles'].map { |r| r['name'] }.join(',')
        end
      end
    end
  end
end
