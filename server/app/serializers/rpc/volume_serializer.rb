module Rpc
  class VolumeSerializer < RpcSerializer

    attr_reader :volume_instance

    def initialize(volume_instance)
      @volume_instance = volume_instance
    end

    def to_hash
      {
        volume_id: @volume_instance.volume.id.to_s,
        volume_instance_id: @volume_instance.id.to_s,
        name: @volume_instance.name,
        driver: @volume_instance.volume.driver,
        driver_opts: @volume_instance.volume.driver_opts
      }
    end

  end
end
