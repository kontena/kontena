require_relative 'common'

module Kontena::Cli::Stacks
  class SearchCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    banner "Search for stacks on the stack registry"

    parameter "[QUERY]", "Query string"

    def execute
      results = stacks_client.search(query.to_s)
      exit_with_error 'Nothing found' if results.empty?
      results.each do |stack|
        puts stack['name']
      end
    end
  end
end

