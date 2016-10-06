require_relative 'common'

module Kontena::Cli::Etcd
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "KEY", "Etcd key"

    option "--recursive", :flag, "Remove keys recursively"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    requires_current_master_token

    def execute
      validate_key
      confirm unless forced?

      data = {}
      data[:recursive] = true if recursive?
      response = client.delete("etcd/#{current_grid}/#{key}", data)

      if response['error']
        exit_with_error response['error']
      end
    end
  end
end
