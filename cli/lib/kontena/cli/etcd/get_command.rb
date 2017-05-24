require_relative 'common'

module Kontena::Cli::Etcd
  class GetCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "ETCD_KEY", "Etcd key", attribute_name: :key

    def execute
      require_api_url
      token = require_token
      validate_key

      response = client(token).get("etcd/#{current_grid}/#{key}")
      if response['value']
        puts response['value']
      elsif response['children']
        exit_with_error "Cannot get value from a directory"
      elsif response['error']
        exit_with_error response['error']
      end
    end
  end
end
