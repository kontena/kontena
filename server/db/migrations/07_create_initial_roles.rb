class CreateInitialRoles < Mongodb::Migration

  def self.up
    Role.create_indexes
    master_admin = Role.create!(name: 'master_admin', description: 'Master admin', )
    Role.create!(name: 'grid_admin', description: 'Grid admin')
    User.first.roles << master_admin if User.count > 0
  end

end
