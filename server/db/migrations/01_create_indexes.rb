class CreateIndexes < Mongodb::Migration

  def self.up
    Mongoid::Tasks::Database.create_indexes
  end
  
end
