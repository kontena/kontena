module Kontena::Cli::Stacks
  module YAML
    class Vault < Opto::Setter
      def set(value)
        require 'shellwords'
        ENV["DEBUG"] && puts("Setting to vault: #{hint}")
        Kontena.run("vault write --silent #{hint} #{value.to_s.shellescape}")
      end
    end
  end
end

