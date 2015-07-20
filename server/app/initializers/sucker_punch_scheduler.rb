require_relative '../services/sucker_punch_scheduler'

SuckerPunchScheduler.supervise if ENV['RACK_ENV'] == 'production'
