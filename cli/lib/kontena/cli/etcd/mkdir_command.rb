require_relative 'common'

module Kontena::Cli::Etcd
  class MkdirCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common

    parameter "KEY", "Etcd key"

    def execute
      require_api_url
      token = require_token
      validate_key
      
      data = {}
      response = client(token).post("etcd/#{current_grid}/#{key}", data)
      if response['error']
        abort response['error']
      end
    end
  end
end
