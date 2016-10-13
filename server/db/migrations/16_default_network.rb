class DefaultNetwork < Mongodb::Migration

  def self.up
    Network.create_indexes

    Grid.each do |grid|
      default_network = Network.create!(
        grid: grid,
        name: 'kontena',
        subnet: '10.81.0.0/16',
        multicast: true,
        internal: false)

      grid.grid_services.each do |service|
        if service.net == 'bridge'
          service.networks << default_network
        end

      end
    end

  end

end
