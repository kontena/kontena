require_relative 'common'

module Kontena::Cli::Stacks
  class SearchCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    parameter '[QUERY]', "Query string"

    requires_current_account_token

    def execute
      puts stacks_client.search(query).inspect
    end
  end
end

