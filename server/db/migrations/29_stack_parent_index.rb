class StackParentIndex < Mongodb::Migration
  def self.up
    Stack.create_indexes
  end
end

