require_relative 'common'

module Kontena::Cli::Stacks
  class PullCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common
    include Common::StackNameParam

    option ['-F', '--file'], '[FILENAME]', "Write to file (default STDOUT)"
    option '--return', :flag, 'Return the result', hidden: true

    def execute
      content = stacks_client.pull(stack_name, stack_version)
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

