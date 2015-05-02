ENV['FIST_OF_FURY_DISABLED'] = 'true'
require_relative '../../app/boot'

task :environment do
  require 'dotenv'
  Dotenv.load
end