class CreateInitialAdmin < Mongodb::Migration
  def self.up
    admin = User.where(email: 'admin').first || User.create!(
      email: 'admin',
      name: 'admin'
    )

    admin.roles << Role.master_admin
    at = AccessToken.create!(
      user: admin,
      scopes: ['user', 'owner'],
      with_code: ENV['KONTENA_INITIAL_ADMIN_CODE'],
      internal: true
    )
    puts "Initial Admin Code: #{at.code}"
  end
end
