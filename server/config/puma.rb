workers Integer(ENV['WEB_CONCURRENCY'] || 1)
threads_count = Integer(ENV['MAX_THREADS'] || 8)
threads threads_count, threads_count
on_worker_boot do
  require_relative '../app/boot'
  require_relative '../app/services/mongodb/migrator'
  Mongodb::Migrator.new.migrate
end
