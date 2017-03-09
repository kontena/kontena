
class VolumeMigration < Mongodb::Migration

  extend VolumesHelpers

  def self.up
    Volume.create_indexes

    GridService.each do |service|
      service.volumes.each do |v|
        begin
          service_volume = build_service_volume(v)
          service.service_volumes << service_volume
          service.save
        rescue Mongoid::Errors::DocumentNotFound
          name = v.split(':')[0]
          Volume.create!(grid: service.grid, name: name, driver: 'local', scope: 'grid')
          retry
        end
      end
    end
  end
end
