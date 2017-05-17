begin
  require 'dotenv'
  Dotenv.load
rescue LoadError
end

task :environment do
  ENV['RACK_ENV'] = 'development' unless ENV['RACK_ENV']

  require 'celluloid/current'
  require 'roda'
  require 'mongoid'
  require 'json'
  require 'mutations'
  require 'logger'
  require 'msgpack'
  require 'tilt/jbuilder.rb'

  Dir[__dir__ + '/../../models/*.rb'].each {|file| require file }
  require_relative '../../app/initializers/00_mongoid'

end
