require_relative 'common'

module Kontena::Cli::Etcd
  class SetCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "ETCD_KEY", "Etcd key", attribute_name: :key
    parameter "VALUE", "Etcd value"

    def execute
      require_api_url
      token = require_token
      validate_key

      data = {value: value}
      response = client(token).post("etcd/#{current_grid}/#{key}", data)
      if response['error']
        exit_with_error response['error']
      end
    end
  end
end
