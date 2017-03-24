module Kontena
  module Models
    class Volume

      attr_reader :name,
                  :labels,
                  :driver,
                  :driver_opts

      # @param [Hash] data
      def initialize(data)
        @name = data['name']
        @labels = data['labels']
        @driver = data['driver']
        @driver_opts = data['driver_opts']
      end
    end
  end
end
