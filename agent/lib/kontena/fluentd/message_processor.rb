require_relative '../helpers/rpc_helper'

module Kontena
  module Fluentd
    class MessageProcessor
      include Celluloid
      include Celluloid::Notifications
      include Kontena::Logging
      include Kontena::Helpers::RpcHelper

      finalizer :close

      def initialize(queue)
        @queue = queue
        @containers = {}
        @messages = 0
        @running = false
        subscribe('websocket:connected', :on_connect) # from master_info RPC
        subscribe('websocket:disconnect', :on_disconnect)
        async.report
      end

      def on_connect(_, _)
        info "websocket connected"
        async.start unless @running
      end

      def on_disconnect(_, _)
        info "websocket disconnected"
        async.stop if @running
      end

      def start
        info "started processing"
        @running = true
        defer { process_messages }
      end

      def report
        every(60) {
          info "queue: #{@queue.size}" if @queue.size > 500
          info "#{@messages / 60} messages per second" if @messages > 0
          @messages = 0
        }
      end

      def process_messages
        while @running && data = @queue.pop
          handle_data(data)
          if @queue.size > 100
            sleep 0.001
          else
            sleep 0.005
          end
        end
      end

      def handle_data(data)
        _, timestamp, record, _ = data
        msg = {
          id: record['container_id'],
          service: record['io.kontena.service.name'],
          stack: record['io.kontena.stack.name'],
          instance: record['io.kontena.service.instance_number'],
          time: Time.at(timestamp).utc.xmlschema,
          type: record['source'],
          data: record['log']
        }
        @messages += 1
        rpc_client.async.notification('/containers/log', [msg])
        Actor[:fluentd_worker].async.on_log_event(msg)
      rescue NoMethodError
        stop
      rescue => exc
        error "#{exc.class.name}: #{exc.message}"
        error exc.backtrace.join("\n") if exc.backtrace
      end

      def stop
        info "stopped processing"
        @running = false
      end
    end
  end
end