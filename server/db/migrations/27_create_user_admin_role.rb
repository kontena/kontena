class CreateUserAdminRole < Mongodb::Migration
  def self.up
    Role.create!(name: 'user_admin', description: 'Invite and remove users')
  end
end
