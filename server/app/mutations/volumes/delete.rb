module Volumes
  class Delete < Mutations::Command

    required do
      model :volume, class: Volume
    end

    def validate
      unless self.volume.services.empty?
        add_error(self.volume.name, :volume_in_use, "Volume still in use in services #{self.volume.services.map{|s| s.to_path}}")
      end
    end

    def execute
      self.volume.destroy
    end

  end

end
