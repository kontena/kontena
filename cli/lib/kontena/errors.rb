module Kontena
  module Errors
    class StandardError < ::StandardError

      attr_reader :status

      # @param status [Fixnum] HTTP response status
      # @param message [String] short error message
      def initialize(status, message)
        @status = status
        super(message)
      end
    end

    # The normal {error: {foo: "invalid foo"}} error response format used by the API
    class StandardErrorHash < StandardError
      attr_reader :errors

      # @param errors [Hash]
      def initialize(status, message, errors)
        super(status, message)
        @errors = errors
      end

      # Render as indented YAML
      def errors_message(indent: "\t")
        @errors.to_yaml.lines[1..-1].map{|line| "#{indent}#{line}" }.join
      end

      # Render the full multi-line message including YAML-formatted errors
      def message
        "#{super}:\n#{errors_message}"
      end
    end

    # An error with an array of additional details
    class StandardErrorArray < Kontena::Errors::StandardError
      # @param details [Array<String>]
      def initialize(status, message, details)
        super(status, message)
        @details = details
      end

      def message
        "#{super}:\n#{@details.map{|msg| "\t" + msg}.join("\n")}"
      end
    end
  end
end
