require_relative 'common'

module Kontena::Cli::Etcd
  class SetCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "KEY", "Etcd key"
    parameter "VALUE", "Etcd value"

    def execute
      require_api_url
      token = require_token
      validate_key

      data = {value: value}
      response = client(token).post("etcd/#{current_grid}/#{key}", data)
      if response['error']
        abort response['error']
      end
    end
  end
end
