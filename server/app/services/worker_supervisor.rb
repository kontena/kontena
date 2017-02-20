class WorkerSupervisor < Celluloid::Supervision::Container
  pool GridServiceSchedulerWorker, as: :grid_service_scheduler_worker, size: 4
  pool StackDeployWorker, as: :stack_deploy_worker
  pool StackRemoveWorker, as: :stack_remove_worker
end
