require_relative '../common'

module Kontena::Cli::Stacks::Registry
  class SearchCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Stacks::Common

    banner "Search for stacks on the stack registry"

    parameter "[QUERY]", "Query string", completion: "REGISTRY_STACK_NAME"

    def execute
      results = stacks_client.search(query.to_s)
      exit_with_error 'Nothing found' if results.empty?
      titles = ['NAME', 'VERSION', 'DESCRIPTION']
      columns = "%-40s %-10s %-40s"
      puts columns % titles
      results.each do |stack|
        puts columns % [stack['stack'], stack['version'] || '?', stack['description'] || '-'] if stack
      end
    end
  end
end
