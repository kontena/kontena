module Volumes
  class Delete < Mutations::Command

    required do
      model :volume, class: Volume
    end

    def validate
      self.volume.grid.grid_services.each do |service|
        service.service_volumes.each do |sv|
          if sv.volume == self.volume
            add_error(service.name, :volume_in_use, "Volume still in use in service #{sv.grid_service.name}")
          end
        end
      end
    end

    def execute
      self.volume.destroy
    end

  end

end
