class WorkerSupervisor < Celluloid::Supervision::Container
  supervise type: RpcServer, as: :rpc_server

  pool GridServiceSchedulerWorker, as: :grid_service_scheduler_worker, size: 4
  pool StackDeployWorker, as: :stack_deploy_worker
end
