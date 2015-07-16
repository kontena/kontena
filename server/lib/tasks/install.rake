
namespace :install do
  task :bootstrap_grid => :environment do
    email = ENV['EMAIL']
    token = ENV['TOKEN']
    initial_size = ENV['SIZE']
    name = ENV['NAME'] || 'default'
    raise "EMAIL must be set" if email.blank?
    raise "TOKEN must be set" if token.blank?
    raise "SIZE must be set" if initial_size.blank?

    user = User.find_or_create_by(email: email)
    outcome = Grids::Create.run(
      user: user,
      initial_size: initial_size,
      name: name
    )
    raise "Cannot create grid" unless outcome.success?

    grid = outcome.result
    grid.update_attribute(:token, token)

    user.grids << grid unless user.grids.include?(grid)
  end
end
