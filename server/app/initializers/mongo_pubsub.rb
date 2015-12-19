require_relative 'mongoid'
require_relative '../services/mongo_pubsub'
require_relative '../models/pubsub_channel'

MongoPubsub.start!(PubsubChannel.collection) if ENV['RACK_ENV'] != 'test'
