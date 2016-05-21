require_relative 'common'

module Kontena::Cli::Etcd
  class RemoveCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "KEY", "Etcd key"

    option "--recursive", :flag, "Remove keys recursively"
    option "--confirm", :flag, "Confirm remove", default: false, attribute_name: :confirmed

    def execute
      require_api_url
      token = require_token
      validate_key
      confirm unless confirmed?

      data = {}
      data[:recursive] = true if recursive?
      response = client(token).delete("etcd/#{current_grid}/#{key}", data)

      if response['error']
        abort response['error']
      end
    end
  end
end
