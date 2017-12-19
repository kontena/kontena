module Kontena::Cli::Stacks
  module YAML
    class Opto::Resolvers::ServiceInstances < ::Opto::Resolver
      include Kontena::Cli::Common

      def resolve
        return nil unless current_master && current_grid
        require 'kontena/cli/stacks/show_command'
        read_command = Kontena::Cli::Stacks::ShowCommand.new([]).instance([self.stack])
        stack = read_command.stack
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
