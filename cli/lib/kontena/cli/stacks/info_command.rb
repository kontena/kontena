require_relative 'common'

module Kontena::Cli::Stacks
  class InfoCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common
    include Common::StackNameParam

    banner "Shows information about a stack on the stacks registry"

    option ['-v', '--versions'], :flag, "Only list available versions"

    requires_current_account_token

    def execute
      unless versions?
        file = YAML::Reader.new(stack_version ? "#{stack_name}:#{stack_version}" : stack_name, skip_variables: true, replace_missing: "filler", from_registry: true)
        puts "CURRENT VERSION"
        puts "-----------------"
        puts "* Version: #{file.yaml['version']}"
        puts
        puts "AVAILABLE VERSIONS"
        puts "-------------------"
      end
      stacks_client.versions(stack_name).map { |s| s['version']}.sort.reverse_each do |version|
        puts version
      end
    end
  end
end

