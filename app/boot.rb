begin
  require 'dotenv'
  Dotenv.load
rescue LoadError
end

ENV['RACK_ENV'] = 'development' unless ENV['RACK_ENV']

require 'roda'
require 'mongoid'
require 'json'
require 'mutations'
require 'logger'
require 'msgpack'
require 'sidekiq'
require 'sidetiq'
require 'tilt/jbuilder.rb'

Dir[__dir__ + '/initializers/*.rb'].each {|file| require file }

Dir[__dir__ + '/helpers/*.rb'].each {|file| require file }

Dir[__dir__ + '/models/*.rb'].each {|file| require file }

Dir[__dir__ + '/mailers/*.rb'].each {|file| require file }

Dir[__dir__ + '/mutations/**/*.rb'].each {|file| require file }

Dir[__dir__ + '/services/**/*.rb'].each {|file| require file }


require_relative 'workers/container_cleanup_worker'
