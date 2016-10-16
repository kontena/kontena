require_relative '../common'

module Kontena::Cli::Grids::Users
  class AddCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Grids::Common

    parameter "[EMAIL]", "Email address"
    parameter "[NAME]", "Grid name"

    def execute
      require_api_url
      token = require_token
      grid = name || current_grid

      if email.nil?
        grid_users = client(token).get("grids/#{grid}/users")['users'].map{ |u| u['email'] }
        master_users = client(token).get('users')['users']
        master_users.delete_if{ |u| grid_users.include?(u['email']) }
        if master_users.size == 0
          exit_with_error("All users in the master already belong to this grid.")
        end
        email = prompt.select("Select user: ") do |menu|
          master_users.each do |user|
            menu.choice user['email'] unless grid_users.include?(user['email'])
          end
        end
      end
      data = { email: email }
      begin
        spinner "Adding user #{pastel.cyan(email)} to grid #{grid}" do
          client(token).post("grids/#{grid}/users", data)
        end
      rescue Kontena::Errors::StandardError => exc
        if exc.status == 404
          exit_with_error("User #{pastel.cyan(email)} does not exist in the master. You need to send invite first.")
        else
          raise exc
        end
      end
    end
  end
end
