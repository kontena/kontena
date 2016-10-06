require_relative '../../common'

module Kontena::Cli::Master::Users
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common

    requires_current_master_token

    def execute
      response = client.get('users')

      response['users'].each do |user|
        roles = user['roles'].map{|r| r['name']}
        puts "#{user['email']} - #{roles.join(', ')}"
      end
    end
  end
end
