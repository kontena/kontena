require_relative 'client'

module EventStream
  class GridEventListener

    attr_reader :grid, :clients

    ##
    # @param [Grid] grid
    def initialize(grid)
      @grid = grid
      @clients = []
      channel = "grids/#{grid.name}"
      @subscription = MongoPubsub.subscribe(channel) do |msg|
        send_message(msg)
      end
    end

    ##
    # Send WebSocket message
    # @param [String] msg
    def send_message(msg)
      valid_clients(msg['event_type']).each do |client|
        client.socket.send(msg.to_json)
      end
    end

    ##
    # Add new websocket client to listener
    #
    # @param [Faye::WebSocket] socket
    # @param [Array<String>] event_types
    def add_client(socket, event_types)
      self.clients << Client.new(socket, event_types)
    end

    ##
    # Remove websocket client from listener
    #
    # @param [Faye::WebSocket] socket
    def remove_client(socket)
      self.clients.delete_if {|client| client.socket == socket }
    end

    ##
    # Find valid clients for event_type
    #
    # @param [String] event_type
    def valid_clients(event_type)
      self.clients.find_all {|client| (client.event_types.include?(event_type) || client.event_types.include?('*')) }
    end
  end
end