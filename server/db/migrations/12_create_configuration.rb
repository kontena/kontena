class CreateConfiguration < Mongodb::Migration
  def self.up
    Configuration.create_indexes
  end
end

