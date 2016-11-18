require_relative '../logging'

module Kontena
  module Helpers
    module WaitHelper
      include Kontena::Logging

      def wait(timeout = 300, message = nil, &block)
        wait_until = Time.now.to_f + timeout
        loop do
          raise ArgumentError, 'no block given' unless block_given?
          value = yield
          return value if value || !still_waiting?(wait_until)
          debug message if message
          sleep 0.5
        end
      end

      def still_waiting?(wait_until)
        wait_until < Time.now.to_f
      end

      def wait!(timeout = 300, message = nil, &block)
        unless wait(timeout, message, &block)
          raise StandarError, "Timeout while: #{message}"
        end
        true
      end

    end
  end
end
