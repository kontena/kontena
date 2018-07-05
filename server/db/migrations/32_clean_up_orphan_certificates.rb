class CleanUpOrphanCertificates < Mongodb::Migration
  def self.up
    Certificate.all.select { |c| c.grid.nil? }.map(&:destroy)
  end

  def self.down
  end
end
