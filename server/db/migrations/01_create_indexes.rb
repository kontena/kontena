class CreateIndexes < Mongodb::Migration
  def up
    Mongoid::Tasks::Database.create_indexes
  end
end
