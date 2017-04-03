module Kontena
  module Errors
    class StandardError < ::StandardError

      attr_reader :status

      def initialize(status, message)
        @status = status
        super(message)
      end
    end

    class DetailsError < Kontena::Errors::StandardError
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
