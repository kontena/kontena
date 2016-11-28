require_relative '../common'

module Kontena::Cli::Stacks::Registry
  class ShowCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Stacks::Common
    include Kontena::Cli::Stacks::Common::StackNameParam

    banner "Shows information about a stack on the stacks registry"

    option ['-v', '--versions'], :flag, "Only list available versions"

    requires_current_account_token

    def execute
      stack = ::YAML.load(stacks_client.show(stack_name))
      puts "#{stack['stack']}:"
      puts "  latest_version: #{stack['version']}"
      puts "  expose: #{stack['expose'] || '-'}"
      puts "  description: #{stack['description'] || '-'}"

      puts "  available_versions:"
      stacks_client.versions(stack_name).map { |s| s['version']}.sort.reverse_each do |version|
        puts "    - #{version}"
      end
    end
  end
end
