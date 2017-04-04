module Kontena::Cli::Stacks
  module YAML
    class Opto::Setters::Vault < ::Opto::Setter
      def set(value)
        require 'shellwords'
        Kontena.run("vault write --silent #{hint} #{value.to_s.shellescape}")
      end
    end
  end
end
