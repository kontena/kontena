Celluloid.logger.level = Logger::ERROR if ENV['RACK_ENV'] == 'production'
Celluloid.boot

require_relative '../../lib/celluloid_tracer' if ENV['DEBUG']
