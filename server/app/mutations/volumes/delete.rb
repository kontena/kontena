module Volumes
  class Delete < Mutations::Command

    required do
      model :volume, class: Volume
    end

    def validate
      self.volume.grid.stacks.each do |stack|
        if stack.external_volumes.find {|e| e == self.volume}
          add_error(service.name, :volume_in_use, "Volume still in use in service #{service.name}")
        end
      end
      if self.volume.stack
        self.volume.stack.grid_services.each do |service|
          if service.volumes.find {|v| v.split(':')[0] == self.volume.name }
            add_error(service.name, :volume_in_use, "Volume still in use in service #{service.name}")
          end
        end
      end
    end

    def execute
      self.volume.destroy
    end

  end

end
