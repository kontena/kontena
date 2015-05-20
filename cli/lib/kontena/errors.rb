module Kontena
  module Errors
    class StandardError < ::StandardError

      def initialize(status, message)
        @status = status
        super(message)
      end
    end
  end
end