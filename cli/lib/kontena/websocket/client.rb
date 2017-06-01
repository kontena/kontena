require 'websocket/driver'
module Kontena
  module Websocket
    module Client
      def self.new(*args)
        Connection.new(*args)
      end
    end
  end
end

require_relative 'client/connection'