require_relative '../common'

module Kontena::Cli::Stacks::Registry
  class PullCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Stacks::Common
    include Kontena::Cli::Stacks::Common::RegistryNameParam

    banner "Pulls / downloads a stack from the stack registry"

    option ['-F', '--file'], '[FILENAME]', "Write to file (default STDOUT)"
    option '--no-cache', :flag, "Don't use local cache"
    option '--return', :flag, 'Return the result', hidden: true

    def execute
      target = no_cache? ? stacks_client : Kontena::StacksCache
      content = target.pull(stack_name.stack_name, stack_name.version)
      if return?
        return content
      elsif file
        File.write(file, content)
        puts pastel.green("Wrote #{content.bytesize} bytes to #{file}")
      else
        puts content
      end
    end
  end
end
