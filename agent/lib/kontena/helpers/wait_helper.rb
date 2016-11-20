require_relative '../logging'

module Kontena
  module Helpers
    module WaitHelper
      include Kontena::Logging


      ##
      # Wait until given block returns truthy value
      #
      # @param timeout [Fixnum] How long to wait
      # @param interval [Fixnum] At what interval is the block yielded
      # @param [String] Message for debugging
      # @param [Block] Block to yield
      # @return [Object] Last return value of the block
      def wait(timeout: 300, interval: 0.5, message: nil, &block)
        wait_until = Time.now.to_f + timeout
        loop do
          raise ArgumentError, 'no block given' unless block_given?
          value = yield
          return value if value || !__still_waiting?(wait_until)
          debug message if message
          sleep interval
        end
      end

      ##
      # Wait until given block returns truthy value
      #
      # @param timeout [Fixnum] How long to wait
      # @param interval [Fixnum] At what interval is the block yielded
      # @param [String] Message for debugging
      # @param [Block] Block to yield
      # @return [Object] Last return value of the block
      # @raise [Timeout::Error] If block does not return truthy value within given timeout
      def wait!(timeout: 300, interval: 0.5, message: nil, &block)
        unless wait(timeout: timeout, interval: interval, message: message, &block)
          raise Timeout::Error, "Timeout while: #{message}"
        end
        true
      end


      def __still_waiting?(wait_until)
        wait_until < Time.now.to_f
      end

    end
  end
end
