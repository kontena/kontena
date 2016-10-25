Mongoid.load!('./config/mongoid.yml', ENV['RACK_ENV'])
Mongoid.raise_not_found_error
Moped.logger.level = Logger::ERROR

# Returns an array such as [3, 0, 12, 0]
mongo_db_version = Mongoid.default_session.command(buildinfo: 1)["versionArray"]

unless mongo_db_version[0] == 3 && mongo_db_version[1] == 0
  abort "MongoDB version 3.0 is required for running Kontena Master. Your version #{mongo_db_version[0]}.#{mongo_db_version[1]}.#{mongo_db_version[2]} is incompatible."
end

