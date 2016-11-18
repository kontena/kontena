require_relative '../logging'

module Kontena
  module Helpers
    module WaitHelper
      include Kontena::Logging

      def wait(timeout = 300, message = nil, &block)
        wait = Time.now.to_f + timeout
        until (value = network_adapter.running?) || (wait < Time.now.to_f)
          value = yield if block
          sleep 0.5
          debug "************" + message if message
        end
        return value
      end

      def wait!(timeout = 300, message = nil, &block)
        unless wait(timeout, message, &block)
          raise StandarError, "Timeout while: #{message}"
        end
      end

    end
  end
end
