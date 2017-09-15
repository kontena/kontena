class JobSupervisor < Celluloid::Supervision::Container
  supervise type: ContainerCleanupJob, as: :container_cleanup_job
  supervise type: DistributedLockCleanupJob, as: :distributed_lock_cleanup_job
  supervise type: NodeCleanupJob, as: :node_cleanup_job
  supervise type: GridSchedulerJob, as: :grid_scheduler_job
  supervise type: LeaderElectorJob, as: :leader_elector_job
  supervise type: TelemetryJob, as: :telemetry_job
  supervise type: GridServiceHealthMonitorJob, as: :service_health_monitor_job
  supervise type: CloudWebsocketClientManager, as: :cloud_websocket_client_manager
  supervise type: CertificateRenewJob, as: :certificate_renew_job
end
