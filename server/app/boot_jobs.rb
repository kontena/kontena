require_relative 'services/job_supervisor'
require_relative 'services/worker_supervisor'
require_relative 'services/mongodb/migrator'

unless ENV['RACK_ENV'] == 'test'
  if servers = ENV['NATS_SERVERS']
    MasterPubsub.start!(servers.split(','))
  else
    MasterPubsub.start!(PubsubChannel)
  end
  JobSupervisor.run!
  WorkerSupervisor.run!
end
