require_relative '../common'

module Kontena::Cli::Stacks::Registry
  class SearchCommand < Kontena::Command
    include Kontena::Cli::Stacks::Common

    banner "Search for stacks on the stack registry"

    parameter "[QUERY]", "Query string"

    option ['-q', '--quiet'], :flag, "Output the identifying column only"

    def execute
      results = stacks_client.search(query.to_s)
      if quiet?
        puts results.map { |s| s['stack'] }.join("\n")
        exit 0
      end
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
