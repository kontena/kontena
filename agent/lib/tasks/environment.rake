require_relative '../kontena-agent'

task :environment do
  require 'dotenv'
  Dotenv.load!
end