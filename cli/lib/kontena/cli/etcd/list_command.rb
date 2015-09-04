
module Kontena::Cli::Etcd
  class ListCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "KEY", "Etcd key"

    def execute
      require_api_url
      token = require_token
      response = client(token).get("etcd/#{current_grid}/#{key}")
      if response['children']
        puts response['children'].join("\n")
      elsif response['value']
        abort "Not a directory"
      elsif response['error']
        abort response['error']
      end
    end
  end
end
