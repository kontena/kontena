
module Kontena::Cli::Etcd
  class ListCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "KEY", "Etcd key"

    option "--recursive", :flag, "List keys recursively", default: false

    def execute
      require_api_url
      token = require_token
      opts = []
      opts << 'recursive=true' if recursive?
      response = client(token).get("etcd/#{current_grid}/#{key}?#{opts.join('&')}")
      if response['children']
        children = response['children'].map{|c| c['key'] }
        puts children.join("\n")
      elsif response['value']
        abort "Not a directory"
      elsif response['error']
        abort response['error']
      end
    end
  end
end
