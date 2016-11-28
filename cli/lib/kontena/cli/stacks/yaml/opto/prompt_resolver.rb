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

      def enum_can_be_other?
        enum? && option.handler.options[:can_be_other] ? true : false
      end

      def enum
        opts = option.handler.options[:options]
        opts << { label: '(Other)', value: nil, description: '(Other)' } if enum_can_be_other?

        answer = prompt.select(question_text) do |menu|
          menu.enum ':' # makes it show numbers before values, you can press the number to select.
          menu.default(opts.index {|opt| opt[:value] == option.default }.to_i + 1) if option.default
          opts.each do |opt|
            menu.choice opt[:label], opt[:value]
          end
        end

        if answer.nil? && enum_can_be_other?
          ask
        else
          answer
        end
      end

      def bool
        prompt.yes?(question_text, default: option.default == false ? false : true)
      end

      def ask
        prompt.ask(question_text, default: option.default)
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

