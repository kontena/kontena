class GridSubnet < Mongodb::Migration

  def self.up
    Network.create_indexes

    Grid.each do |grid|
      # using save will write the implicit subnet/supernet field default SUBNET/SUPERNET values
      grid.save
    end
  end
end
