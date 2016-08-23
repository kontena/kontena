class CreateInitialAdmin < Mongodb::Migration
  def self.up
    User.create_indexes
    if User.count == 0
      admin = User.create!(
        email: 'admin',
        name: 'admin'
      )
      admin.roles << Role.master_admin
      AccessToken.create!(
        user: admin,
        scopes: ['user', 'owner'],
        with_code: ENV['KONTENA_INITIAL_ADMIN_CODE'],
        internal: true
      )
    end
  end
end
