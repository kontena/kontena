require_relative 'grid_event_listener'

module EventStream
  class GridEventServer
    LISTENERS = []

    ##
    # @param [Faye::WebSocket] ws
    # @param [Grid] grid_name
    # @param [Hash]
    def self.serve(ws, grid, params)

      ws.on :open do |event|
        listener = self.find_listener(grid) || self.create_listener(grid)
        if params['event_types']
          event_types = params['event_types'].split(',')
        else
          event_types = ['*']
        end
        listener.add_client(ws, event_types)
        access_token = AccessToken.find_by(token: params['token'])
        access_token.delete if access_token
      end

      ws.on :close do |event|
        listener = find_listener(grid)
        listener.remove_client(ws) if listener
      end
      ws.rack_response
    end


    ##
    # @param [Grid] grid
    # @return GridEventListener
    def self.find_listener(grid)
      LISTENERS.find {|subscriber| subscriber.grid.id == grid.id }
    end

    ##
    # @param [Grid] grid
    # @return GridEventListener
    def self.create_listener(grid)
      listener = GridEventListener.new(grid)
      LISTENERS << listener
      listener
    end
  end
end