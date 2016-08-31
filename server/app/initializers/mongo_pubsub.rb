require_relative 'mongoid'
require_relative '../services/mongo_pubsub'
require_relative '../models/pubsub_channel'

unless ENV['RACK_ENV'] == 'test' || ENV['NO_MONGO_PUBSUB']
  MongoPubsub.start!(PubsubChannel.collection)
end
