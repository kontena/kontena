class JobSupervisor < Celluloid::SupervisionGroup
  supervise ContainerCleanupJob, as: :container_cleanup_job
  supervise DistributedLockCleanupJob, as: :distributed_lock_cleanup_job
  supervise NodeCleanupJob, as: :node_cleanup_job
  supervise ServiceBalancerJob, as: :service_balancer_job
end
