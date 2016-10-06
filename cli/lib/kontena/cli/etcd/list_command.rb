require_relative 'common'

module Kontena::Cli::Etcd
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "KEY", "Etcd key"

    option "--recursive", :flag, "List keys recursively", default: false

    requires_current_master_token

    def execute
      validate_key

      opts = []
      opts << 'recursive=true' if recursive?
      response = client.get("etcd/#{current_grid}/#{key}?#{opts.join('&')}")
      if response['children']
        children = response['children'].map{|c| c['key'] }
        puts children.join("\n")
      elsif response['value']
        exit_with_error "Not a directory"
      elsif response['error']
        exit_with_error response['error']
      end
    end
  end
end
