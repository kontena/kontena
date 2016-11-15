class GridSubnet < Mongodb::Migration

  def self.up
    Network.create_indexes

    Grid.each do |grid|
      grid.subnet = Grid.SUBNET unless grid.subnet
      grid.supernet = Grid.SUPERNET unless grid.supernet
    end
  end
end
