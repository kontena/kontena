require_relative '../common'

module Kontena::Cli::Grids::Users
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Grids::Common

    parameter "[EMAIL]", "Email address"
    parameter "[NAME]", "Grid name"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      token = require_token
      grid = name || current_grid
      if email.nil?
        grid_users = client(token).get("grids/#{grid}/users")['users']
        email = prompt.select("Select user: ") do |menu|
          grid_users.each do |user|
            roles = user['roles'].map{|r| r['name']}
            roles << 'user' if roles.empty?
            menu.choice "#{user['email']} (#{roles.join(',')})", user['email']
          end
        end
      else
        confirm_command(email) unless forced?
      end
      spinner "Removing user #{pastel.cyan(email)} from the grid #{pastel.cyan(grid)}" do |s|
        client(token).delete("grids/#{grid}/users/#{email}")
      end
    end
  end
end
