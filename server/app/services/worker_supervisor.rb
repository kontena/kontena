class WorkerSupervisor < Celluloid::SupervisionGroup
  pool GridSchedulerWorker, as: :grid_scheduler_worker
  pool GridServiceSchedulerWorker, as: :grid_service_scheduler_worker, size: 4
  pool GridServiceRemoveWorker, as: :grid_service_remove_worker
  pool StackDeployWorker, as: :stack_deploy_worker
  pool StackRemoveWorker, as: :stack_remove_worker
end
