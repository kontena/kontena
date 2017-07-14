class GridWeaveSecret < Mongodb::Migration
  def self.up
    Grid.all.each do |grid|
      grid.set(:weave_secret => grid.token)
    end
  end
end
