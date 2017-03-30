module Kontena
  module Helpers
    module StatsHelper
    
      # @param [Array<Hash>] prev_interfaces
      # @param [Array<Hash>] current_interfaces
      # @param [Number] interval_seconds
      def calculate_interface_traffic(prev_interfaces, current_interfaces, interval_seconds)
        interfaces = []
        rx_bytes = 0
        prev_rx_bytes = 0
        tx_bytes = 0
        prev_tx_bytes = 0

        results = current_interfaces.inject(results) { |result, iface|
          interfaces << iface[:name]
          rx_bytes += iface[:rx_bytes]
          tx_bytes += iface[:tx_bytes]

          prev_iface = prev_interfaces.select { |x| x[:name] == iface[:name] }

          if (prev_iface.size > 0)
            prev_rx_bytes += prev_iface[0][:rx_bytes]
            prev_tx_bytes += prev_iface[0][:tx_bytes]
          end

          result
        }

        rx_bytes_per_second = ((rx_bytes - prev_rx_bytes).to_f / interval_seconds).round
        tx_bytes_per_second = ((tx_bytes - prev_tx_bytes).to_f / interval_seconds).round

        {
          interfaces: interfaces,
          rx_bytes: rx_bytes,
          rx_bytes_per_second: rx_bytes_per_second,
          tx_bytes: tx_bytes,
          tx_bytes_per_second: tx_bytes_per_second
        }
      end

    end
  end
end
