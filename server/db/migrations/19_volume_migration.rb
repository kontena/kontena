
class VolumeMigration < Mongodb::Migration

  extend VolumesHelpers

  def self.up
    Volume.create_indexes

    GridService.each do |service|
      service.volumes.each do |v|
        volume_spec = parse_volume(v)
        if volume_spec[:volume]
          volume = service.grid.volumes.find_by(name: volume_spec[:volume])
          unless volume
            volume = Volume.create!(grid: service.grid, name: volume_spec[:volume], driver: 'local', scope: 'grid')
          end
          volume_spec[:volume] = volume
        end

        service.service_volumes << ServiceVolume.new(**volume_spec)
        service.save
      end
    end
  end
end
