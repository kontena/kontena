class CreateGridServiceInstance < Mongodb::Migration
  def self.up
    GridServiceInstance.create_indexes
    migrate_containers('volume')
    migrate_containers('container')
  end

  def self.migrate_containers(container_type)
    Container.unscoped.where(container_type: container_type).includes(:grid_service).each do |c|
      if c.grid_service && c.grid_service.grid_service_instances.find_by(instance_number: c.instance_number).nil?
        c.grid_service.grid_service_instances.create!(
          host_node_id: c.host_node_id,
          desired_state: self.desired_state(c.grid_service),
          state: self.container_state(c),
          instance_number: c.instance_number,
          deploy_rev: c.label('io.kontena.container.deploy_rev')
        )
      end
    end
  end

  def self.desired_state(grid_service)
    if grid_service.initialized?
      'initialized'
    elsif grid_service.running? || grid_service.deploying?
      'running'
    else
      'stopped'
    end
  end

  def self.container_state(container)
    if container.running?
      'running'
    else
      'stopped'
    end
  end
end
