class GridSubnet < Mongodb::Migration

  def self.up
    Network.create_indexes

    Grid.each do |grid|
      # write default values to database if missing
      grid.set_domain_default
      grid.save
    end
  end
end
