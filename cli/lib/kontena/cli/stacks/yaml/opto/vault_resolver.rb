module Kontena::Cli::Stacks
  module YAML
    class Opto::Resolvers::Vault < Opto::Resolver
      def resolve
        require 'shellwords'
        Kontena.run("vault read --return #{hint.shellescape}", returning: :result)
      end
    end
  end
end
