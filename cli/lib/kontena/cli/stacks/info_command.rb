require_relative 'common'

module Kontena::Cli::Stacks
  class InfoCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common
    include Common::StackNameParam

    option ['-v', '--versions'], :flag, "Only list available versions"

    def execute
      unless versions?
        file = YAML::Reader.new(stack_name, skip_variables: true, replace_missing: "filler", from_registry: true)
        puts "CURRENT VERSION"
        puts "-----------------"
        puts "* Version: #{file.yaml['version']}"
        puts
        puts "AVAILABLE VERSIONS"
        puts "-------------------"
      end
      # registry returns an array of strings now, going to change to [{ "version" => "0.1" }] soon, thats why .map
      stacks_client.versions(stack_name).sort.reverse.each do |version|
        puts version.kind_of?(String) ? version : version['version'] 
      end
    end
  end
end

