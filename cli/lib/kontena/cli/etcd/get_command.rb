require_relative 'common'

module Kontena::Cli::Etcd
  class GetCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "KEY", "Etcd key"

    requires_current_master_token

    def execute
      validate_key

      response = client.get("etcd/#{current_grid}/#{key}")
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
