module EventStream
  class Client
    attr_reader :socket, :event_types

    def initialize(socket, event_types)
      @socket = socket
      @event_types = event_types
    end
  end
end