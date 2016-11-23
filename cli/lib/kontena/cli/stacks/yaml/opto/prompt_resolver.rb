module Kontena::Cli::Stacks
  module YAML
    class Prompt < Opto::Resolver
      include Kontena::Cli::Common

      def enum?
        option.type == 'enum'
      end

      def question_text
        (!hint.nil? && hint != option.name) ? "#{hint} :" : "#{enum? ? "Select" : "Enter"} #{option.label || option.name} :"
      end

      def enum
        prompt.select(question_text) do |menu|
          option.handler.options[:options].each do |opt| # quite ugly way to access the option's value list definition
            menu.choice opt[:label], opt[:value]
          end
        end
      end

      def ask
        TTY::Prompt.new.ask(question_text)
      end


      def resolve
        return nil if option.skip?
        enum? ? enum : ask
      end
    end
  end
end

