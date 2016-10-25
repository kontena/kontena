namespace :kontena do
  desc 'Reset internal administrator account'
  task :reset_admin => :environment do
    ENV['INITIAL_ADMIN_CODE'] = SecureRandom.hex(6)
    ENV['NO_MONGO_PUBSUB'] = 'true'
    ENV['RACK_ENV']    ||= 'production'
    ENV['MONGODB_URI'] ||= 'mongodb://mongodb:27017/kontena_server'
    require_relative '../../app/boot'
    Celluloid.logger.level = Logger::ERROR
    require_relative '../../db/migrations/14_create_initial_admin'
    CreateInitialAdmin.up
    puts "Kontena Master Internal administrator account has been reset."
    puts
    puts "To authenticate your kontena-cli use this command:"
    puts "kontena master login --code #{ENV['INITIAL_ADMIN_CODE']} #{Configuration['server.root_url'] || "<master_url>"}"
  end
end
