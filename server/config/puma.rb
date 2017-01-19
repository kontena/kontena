require 'etc'

workers Integer(ENV['WEB_CONCURRENCY'] || Etc.nprocessors)
threads_count = Integer(ENV['MAX_THREADS'] || 8)
threads threads_count, threads_count
on_worker_boot do |worker_num|
  # Run migrations only on first worker, worker_num is zero based
  if worker_num == 0
    require_relative '../app/boot'
    require_relative '../app/services/mongodb/migrator'
    Mongodb::Migrator.new.migrate
  end
end
