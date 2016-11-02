class WorkerSupervisor < Celluloid::SupervisionGroup
  pool GridSchedulerWorker, as: :grid_scheduler_worker
  pool GridServiceSchedulerWorker, as: :grid_service_scheduler_worker, size: 4
  pool GridServiceRemoveWorker, as: :grid_service_remove_worker
end
