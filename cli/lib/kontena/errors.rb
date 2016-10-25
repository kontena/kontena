module Kontena
  module Errors
    class StandardError < ::StandardError

      attr_reader :status

      def initialize(status, message)
        @status = status
        super(message)
      end
    end
  end
end
