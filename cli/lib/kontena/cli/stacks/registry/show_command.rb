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
      require 'semantic'
      require "safe_yaml"
      SafeYAML::OPTIONS[:default_mode] = :safe
      unless versions?
        stack = ::YAML.safe_load(stacks_client.show(stack_name, stack_version))
        puts "#{stack['stack']}:"
        puts "  #{"latest_" unless stack_version}version: #{stack['version']}"
        puts "  expose: #{stack['expose'] || '-'}"
        puts "  description: #{stack['description'] || '-'}"

        puts "  available_versions:"
      end

      stacks_client.versions(stack_name).reject {|s| s['version'].nil? || s['version'].empty?}.map { |s| Semantic::Version.new(s['version'])}.sort.reverse_each do |version|
        puts versions? ? version : "    - #{version}"
      end
    end
  end
end
