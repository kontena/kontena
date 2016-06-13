module Kontena
  module Cli
    module Containers
      module ContainersHelper

        # @param [Array<String>] args
        # @return [String]
        def build_command(args)
          return args.first if args.size == 1

          args.reduce('') do |cmd, arg|
            if arg.include?(' ') || arg.include?('"')
              arg = '"' + arg.gsub('"', '\\"') + '"'
            end
            cmd + ' ' + arg
          end.strip
        end

      end
    end
  end
end
