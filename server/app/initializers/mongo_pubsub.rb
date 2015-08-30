require_relative 'mongoid'
require_relative '../services/mongo_pubsub'

MongoPubsub.start!(PubsubChannel.collection) if ENV['RACK_ENV'] != 'test'
