require 'tty-prompt'
require 'pastel'

module Kontena
  class LightPrompt

    attr_reader :prompt

    extend Forwardable

    class Menu
      attr_reader :choices, :calls

      def initialize
        @choices = []
        @calls = {}
      end

      def choice(text, label)
        choices << [text, label]
      end

      def add_quit_choice
        choice('(done)', :done)
      end

      def remove_choice(value)
        choices.reject! { |c| c.last == value }
      end

      def remove_choices(values)
        values.each { |v| remove_choice(v) }
      end

      def method_missing(meth, *args)
        calls[meth] = args
      end

      def respond_to_missing?(meth, privates = false)
        prompt.respond_to?(meth, privates)
      end
    end

    def initialize(options={})
      @prompt = TTY::Prompt.new(options)
    end

    def select(*args, &block)
      choice_collector = Menu.new
      yield choice_collector

      prompt.enum_select(*args) do |menu|
        choice_collector.calls.each do |meth, args|
          if menu.respond_to?(meth)
            menu.send(meth, *args)
          end
        end
        choice_collector.choices.each do |choice|
          menu.choice choice.first, choice.last
        end
      end
    end

    def multi_select(*args, &block)
      choice_collector = Menu.new
      yield choice_collector
      choice_collector.add_quit_choice

      selections = []

      loop do
        choice_collector.remove_choices(selections)

        answer = prompt.enum_select(*args) do |menu|
          choice_collector.calls.each do |meth, args|
            if menu.respond_to?(meth)
              menu.send(meth, *args)
            end
          end
          choice_collector.choices.each do |choice|
            menu.choice choice.first, choice.last
          end
        end

        break if answer == :done
        selections << answer
      end

      selections
    end


    def_delegators :prompt, :ask, :yes?, :error

    def method_missing(meth, *args)
      prompt.send(meth, *args)
    end

    def respond_to_missing?(meth, privates = false)
      prompt.respond_to?(meth, privates)
    end
  end
end
