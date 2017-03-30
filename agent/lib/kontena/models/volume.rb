module Kontena
  module Models
    class Volume

      attr_reader :volume_instance_id,
                  :name,
                  :labels,
                  :driver,
                  :driver_opts

      # @param [Hash] data
      def initialize(data)
        @volume_instance_id = data['volume_instance_id']
        @name = data['name']
        @labels = {
          'io.kontena.volume_instance.id' => @volume_instance_id,
          'io.kontena.volume.id' => data['volume_id']
        }
        @driver = data['driver']
        @driver_opts = data['driver_opts']
      end
    end
  end
end
