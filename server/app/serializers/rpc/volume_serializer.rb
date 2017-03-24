module Rpc
  class VolumeSerializer

    attr_reader :volume_instance

    def initialize(volume_instance)
      @volume_instance = volume_instance
    end

    def to_hash
      {
        name: @volume_instance.name,
        driver: @volume_instance.volume.driver,
        driver_opts: @volume_instance.volume.driver_opts,
        labels: {
          'io.kontena.volume.id' => @volume_instance.volume.id.to_s
        }
      }
    end

  end
end
