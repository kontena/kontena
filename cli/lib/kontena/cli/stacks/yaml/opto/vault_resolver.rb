module Kontena::Cli::Stacks
  module YAML
    class Opto::Resolvers::Vault < Opto::Resolver
      def resolve
        raise RuntimeError, "Missing or empty vault secret name" if hint.to_s.empty?
        require 'shellwords'
        Kontena.run("vault read --return #{hint.shellescape}", returning: :result)
      end
    end
  end
end
