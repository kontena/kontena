class AddConfigTimestampsAndIndex < Mongodb::Migration
  def self.up
    Configuration.create_indexes
    Configuration.all.map(&:touch)
  end
end


