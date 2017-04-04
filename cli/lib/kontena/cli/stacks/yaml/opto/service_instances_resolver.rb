module Kontena::Cli::Stacks
  module YAML
    class Opto::Resolvers::ServiceInstances < ::Opto::Resolver
      def resolve
        read_command = Kontena::Cli::Stacks::ShowCommand.new([])
        stack = read_command.fetch_stack(self.stack)
        service = stack['services'].find { |s| s['name'] == hint }
        if service
          service['instances']
        else
          nil
        end
      rescue Kontena::Errors::StandardError
        nil
      end

      def stack
        ENV['STACK']
      end
    end
  end
end
