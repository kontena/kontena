require_relative '../common'

module Kontena::Cli::Stacks::Registry
  class ShowCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Stacks::Common
    include Kontena::Cli::Stacks::Common::RegistryNameParam

    banner "Shows information about a stack on the stacks registry"

    option ['-v', '--versions'], :flag, "Only list available versions"

    requires_current_account_token

    def execute
      unless versions?
        data = stacks_client.show(stack_name).dig('data', 'attributes')
        puts "#{data['organization-id']}/#{data['name']}:"
        puts "  description: #{data.dig('latest-version', 'description')}"
        puts "  latest_version: #{data.dig('latest-version', 'version') || '-'}"
        puts "  created_at: #{data.dig('created-at')}"
        puts "  pulls: #{data.dig('pulls')}"
        puts "  private: #{data.dig('is-private')}"
        puts "  available_versions:"
      end

      stacks_client.versions(stack_name).each do |version|
        puts versions? ? version['attributes']['version'] : "    - #{version['attributes']['version']} (#{version['attributes']['created-at']})"
      end
    end
  end
end
