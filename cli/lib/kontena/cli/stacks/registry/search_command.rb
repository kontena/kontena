require_relative '../common'

module Kontena::Cli::Stacks::Registry
  class SearchCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Stacks::Common
    include Kontena::Cli::TableGenerator::Helper

    banner "Search for stacks on the stack registry"

    parameter "[QUERY]", "Query string"

    option ['--[no-]pre'], :flag, "Include pre-release versions", default: true
    option ['--[no-]private'], :flag, "Include private stacks", default: true, attribute_name: :priv

    option ['--tag', '-t'], '[TAG]', "Search by tags", multivalued: true

    option ['-q', '--quiet'], :flag, "Output the identifying column only"

    def fields
      quiet? ? ['name'] : %w(name version pulls description)
    end

    def execute
      results = stacks_client.search(query.to_s, tags: tag_list, include_prerelease: pre?, include_private: priv?)
      exit_with_error 'Nothing found' if results.empty?
      print_table(results.map { |r| r['attributes'] }) do |row|
        next if quiet?
        row['name'] = '%s/%s' % [row['organization-id'], row['name']]
        row['name'] = pastel.yellow(row['name']) if row['is-private']
        if row['latest-version'] && row['latest-version']['version']
          row['version'] = row['latest-version']['version']
          row['description'] = row['latest-version']['description']
        else
          row['version'] = '?'
        end

        row['description'] = '-' if row['description'].to_s.empty?
      end
    end
  end
end
