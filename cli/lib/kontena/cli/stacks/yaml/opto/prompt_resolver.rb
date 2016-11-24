if RUBY_VERSION < '2.1'
  require 'opto/extensions/hash_string_or_symbol_key'
  using Opto::Extension::HashStringOrSymbolKey
end

module Kontena::Cli::Stacks
  module YAML
    class Prompt < Opto::Resolver
      include Kontena::Cli::Common

      using Opto::Extension::HashStringOrSymbolKey unless RUBY_VERSION < '2.1'

      def enum?
        option.type == 'enum'
      end

      def boolean?
        option.type == 'boolean'
      end

      def prompt_word
        return "Select" if enum?
        return "Enable" if boolean?
        "Enter"
      end

      def question_text
        (!hint.nil? && hint != option.name) ? "#{hint} :" : "#{prompt_word} #{option.label || option.name} :"
      end

      def enum
        prompt.select(question_text) do |menu|
          option.handler.options[:options].each do |opt| # quite ugly way to access the option's value list definition
            menu.choice opt[:label], opt[:value]
          end
        end
      end

      def bool
        prompt.yes?(question_text)
      end

      def ask
        TTY::Prompt.new.ask(question_text)
      end


      def resolve
        return nil if option.skip?
        if enum?
          enum
        elsif boolean?
          bool
        else
          ask
        end
      end
    end
  end
end

