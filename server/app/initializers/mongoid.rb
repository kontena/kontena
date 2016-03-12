Mongoid.load!('./config/mongoid.yml', ENV['RACK_ENV'])
Mongoid.raise_not_found_error
Moped.logger.level = Logger::ERROR
