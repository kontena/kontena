if ENV['NATS_SERVERS']
  require_relative '../services/pubsub/nats'
  Kernel.const_set('MasterPubsub', Pubsub::Nats)
else
  require_relative '../services/pubsub/mongo'
  Kernel.const_set('MasterPubsub', Pubsub::Mongo)
end
