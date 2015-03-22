class GridStatWorker
  include Sidekiq::Worker
  include Sidetiq::Schedulable

  sidekiq_options(retry: false)
  recurrence { minutely }

  def perform
    Grid.all.each do |grid|
      running_count = grid.containers.where('info.State.Running' => true).count
      not_running_count = grid.containers.where('info.State.Running' => false).count
      GridStat.create(
          grid: grid,
          running_containers: running_count,
          not_running_containers: not_running_count
      )
    end

  end
end
