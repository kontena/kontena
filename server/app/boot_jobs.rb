require_relative 'services/job_supervisor'
require_relative 'services/mongodb/migrator'

unless ENV['RACK_ENV'] == 'test'
  JobSupervisor.run!
  Mongodb::Migrator.new.async.migrate
end
