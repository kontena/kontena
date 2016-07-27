require_relative 'common'

module Kontena::Cli::Stacks
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "NAME", "Stack name"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      token = require_token

      confirm_command(name) unless forced?
      spinner "Removing stack #{pastel.cyan(name)} " do
        remove_stack(token, name)
      end
    end

    def remove_stack(token, name)
      client(token).delete("stacks/#{current_grid}/#{name}")
    end
  end
end
