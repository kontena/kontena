begin
  require 'dotenv'
  Dotenv.load
rescue LoadError
end

ENV['RACK_ENV'] = 'development' unless ENV['RACK_ENV']

require 'eventmachine'
require 'celluloid'
require 'roda'
require 'mongoid'
require 'json'
require 'mutations'
require 'logger'
require 'msgpack'
require 'tilt/jbuilder.rb'
require 'mongoid/enum'

Dir[__dir__ + '/initializers/*.rb'].sort.each {|file| require file }

Dir[__dir__ + '/authorizers/*.rb'].each {|file| require file }

Dir[__dir__ + '/models/*.rb'].each {|file| require file }

Dir[__dir__ + '/helpers/*.rb'].each {|file| require file }

Dir[__dir__ + '/mutations/**/*.rb'].each {|file| require file }

Dir[__dir__ + '/jobs/**/*.rb'].each {|file| require file }

Dir[__dir__ + '/services/**/*.rb'].each {|file| require file }

