require_relative '../logging'

module Kontena
  module Helpers
    module WaitHelper
      include Kontena::Logging

      ##
      # Wait until given block returns truthy value
      #
      # @param message [String] Message for debugging
      # @param timeout [Fixnum] How long to wait
      # @param interval [Fixnum] At what interval is the block yielded
      # @yield Check if still waiting
      # @yieldreturn [Boolean] false if still waiting
      # @return falsey on timeout, or truthy return value from block
      def wait(message, timeout: 300, interval: 0.5, &block)
        wait_until = Time.now.to_f + timeout
        loop do
          raise ArgumentError, 'no block given' unless block_given?
          value = yield
          return value if value || Time.now.to_f > wait_until
          debug "wait #{message}" if message
          sleep interval
        end
      end

      ##
      # Wait until given block returns truthy value
      #
      # @see wait
      # @param message [String] Message for debugging
      # @return truthy return value of the block
      # @raise [Timeout::Error] If block does not return truthy value within given timeout
      def wait!(message, **options, &block)
        unless wait(message, **options, &block)
          raise Timeout::Error, "Timeout while: #{message}"
        end
        true
      end
    end
  end
end
