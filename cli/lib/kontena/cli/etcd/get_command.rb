require_relative 'common'

module Kontena::Cli::Etcd
  class GetCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "KEY", "Etcd key"

    def execute
      require_api_url
      token = require_token
      validate_key

      response = client(token).get("etcd/#{current_grid}/#{key}")
      if response['value']
        puts response['value']
      elsif response['children']
        abort "Cannot get value from a directory"
      elsif response['error']
        abort response['error']
      end
    end
  end
end
