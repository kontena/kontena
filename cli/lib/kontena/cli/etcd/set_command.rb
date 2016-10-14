require_relative 'common'

module Kontena::Cli::Etcd
  class SetCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "KEY", "Etcd key"
    parameter "VALUE", "Etcd value"

    requires_current_master_token

    def execute
      validate_key

      data = {value: value}
      response = client.post("etcd/#{current_grid}/#{key}", data)
      if response['error']
        exit_with_error response['error']
      end
    end
  end
end
