require_relative 'services/job_supervisor'
require_relative 'services/worker_supervisor'
require_relative 'services/mongodb/migrator'

unless ENV['RACK_ENV'] == 'test' || ENV['NO_MONGO_PUBSUB']
  MongoPubsub.start!(PubsubChannel)

  WorkerSupervisor.run!
  JobSupervisor.run!
end
