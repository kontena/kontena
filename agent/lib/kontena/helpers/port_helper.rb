  module Kontena
    module Helpers
      module PortHelper

        def container_port_open?(ip, port, timeout = 2.0)
          Timeout::timeout(timeout) do
            begin
              TCPSocket.new(ip, port).close
              true
            rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
              false
            end
          end
        rescue Timeout::Error
          false
        end

      end
    end
  end