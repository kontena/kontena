module Kontena::Cli::Stacks
  module YAML
    class Secret < Opto::Types::String
      using Opto::Extension::HashStringOrSymbolKey

      Opto::Type.inherited(self)

      def after_set(option)
        if option.valid?
          require 'shellwords'
          require 'byebug'; byebug
          ENV["DEBUG"] && puts("Setting to vault: #{options[:secret][:secret]}")
          Kontena.run("vault write --silent #{options[:secret][:secret]} #{option.value.to_s.shellescape}")
        else
          ENV["DEBUG"] && puts("Option #{option.name} not valid, not setting to vault")
        end
      end
    end
  end
end

