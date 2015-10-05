require_relative 'services/job_supervisor'

JobSupervisor.run! unless ENV['RACK_ENV'] == 'test'
