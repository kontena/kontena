require_relative 'common'

module Kontena::Cli::Etcd
  class ListCommand < Kontena::Command
    include Kontena::Cli::GridOptions
    include Common

    parameter "[KEY]", "Etcd key", default: '/'

    option ['-r', '--recursive'], :flag, "List keys recursively", default: false

    # the command outputs id info only anyway, this is here strictly for ignoring purposes
    option ['-q', '--quiet'], :flag, "Output the identifying column only", hidden: true

    requires_current_master
    requires_current_master_token

    def execute
      validate_key

      response = spin_if(!quiet?, "Retrieving keys from etcd") do
        client.get("etcd/#{current_grid}/#{key}#{'?recursive=true' if recursive?}")
      end

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
