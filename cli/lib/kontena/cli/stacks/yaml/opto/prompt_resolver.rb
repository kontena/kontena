module Kontena::Cli::Stacks
  module YAML
    class Prompt < Opto::Resolver
      include Kontena::Cli::Common

      def resolve
        prompt.ask(hint)
      end
    end
  end
end

