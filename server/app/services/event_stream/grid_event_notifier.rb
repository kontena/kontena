module EventStream
  module GridEventNotifier
    ##
    # @param [Grid] grid
    # @param [String] event_type
    # @param [String] action
    # @param [Object] payload
    def trigger_grid_event(grid, event_type, action, payload)
      MongoPubsub.publish_async("grids/#{grid.name}", {'event_type' => event_type, 'action' => action, 'payload' => payload})
    end
  end
end