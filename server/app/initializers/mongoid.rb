Mongoid.load!('./config/mongoid.yml', ENV['RACK_ENV'])
Mongoid.raise_not_found_error

require_relative '../services/mongo_pubsub'
MongoPubsub.start!(PubsubChannel.collection) if ENV['RACK_ENV'] != 'test'
