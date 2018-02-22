module Rpc
  class VolumeSerializer < RpcSerializer

    attribute :volume_id
    attribute :volume_instance_id
    attribute :name
    attribute :driver
    attribute :driver_opts

    def volume_id
      object.volume.id.to_s
    end

    def volume_instance_id
      object.id.to_s
    end

    def name
      object.name
    end

    def driver
      object.driver
    end

    def driver_opts
      object.volume.driver_opts
    end

  end
end
