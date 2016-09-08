require_relative 'services/job_supervisor'
require_relative 'services/worker_supervisor'
require_relative 'services/mongodb/migrator'

unless ENV['RACK_ENV'] == 'test'
  MongoPubsub.start!(PubsubChannel.collection)
  JobSupervisor.run!
  Mongodb::Migrator.new.migrate
end

WorkerSupervisor.run!
