class StackLabelsRebuildIndexes < Mongodb::Migration
  def self.up
    info "recreating stack indexes, this might take long time"
    Stack.create_indexes
  end
end
