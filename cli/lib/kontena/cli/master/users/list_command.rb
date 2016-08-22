require_relative '../../common'

module Kontena::Cli::Master::Users
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common

    def execute
      require_api_url
      token = require_token
      response = client(token).get('users')

      response['users'].each do |user|
        roles = user['roles'].map{|r| r['name']}
        puts "#{user['email']} - #{roles.join(', ')}"
      end
    end
  end
end
