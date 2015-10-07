class JobSupervisor < Celluloid::SupervisionGroup
  supervise CollectionIndexerJob, as: :collection_indexer_job
  supervise ContainerCleanupJob, as: :container_cleanup_job
  supervise DistributedLockCleanupJob, as: :distributed_lock_cleanup_job
  supervise NodeCleanupJob, as: :node_cleanup_job
end
