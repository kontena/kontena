class WorkerSupervisor < Celluloid::Supervision::Container
  pool GridServiceDeployWorker, as: :grid_service_deploy_worker, size: 4
  pool StackDeployWorker, as: :stack_deploy_worker
  pool StackRemoveWorker, as: :stack_remove_worker
end
