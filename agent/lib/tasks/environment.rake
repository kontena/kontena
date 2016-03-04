require_relative '../kontena-agent'

task :environment do
  begin
    require 'dotenv'
    Dotenv.load
  rescue LoadError
  end
end
