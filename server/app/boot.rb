begin
  require 'dotenv'
  Dotenv.load
rescue LoadError
end

ENV['RACK_ENV'] = 'development' unless ENV['RACK_ENV']

require 'eventmachine'
require 'celluloid/current'
require 'roda'
require 'mongoid'
require 'json'
require 'mutations'
require 'logger'
require 'msgpack'
require 'tilt/jbuilder.rb'
require 'mongoid/enum'
require 'json_serializer'
require 'lru_redux'

def require_glob(glob)
  Dir.glob(glob).sort.each do |path|
    require path
  end
end

require_glob __dir__ + '/initializers/*.rb'
require_glob __dir__ + '/authorizers/*.rb'
require_glob __dir__ + '/models/*.rb'
require_glob __dir__ + '/helpers/*.rb'
require_glob __dir__ + '/mutations/**/*.rb'
require_glob __dir__ + '/jobs/**/*.rb'
require_glob __dir__ + '/services/**/*.rb'
require_glob __dir__ + '/serializers/**/*.rb'
