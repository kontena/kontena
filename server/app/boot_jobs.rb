require_relative 'services/job_supervisor'
require_relative 'services/worker_supervisor'
require_relative 'services/mongodb/migrator'

if ENV['REDIS_URL']
  require_relative 'services/pubsub/redis'
  MasterPubsub = Pubsub::Redis
else
  require_relative 'services/pubsub/mongo'
  MasterPubsub = Pubsub::Mongo
end

unless ENV['RACK_ENV'] == 'test'
  if ENV['REDIS_URL']
    MasterPubsub.start!(ENV['REDIS_URL'])
  else
    MasterPubsub.start!(PubsubChannel)
  end
  JobSupervisor.run!
  WorkerSupervisor.run!
end
