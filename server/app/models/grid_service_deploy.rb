# States:
#   - created: created_at=T0
#       GridServices::Deploy request, or some internal scheduler, decides to deploy the service
#   - queued: created_at=T0 queued_at=T1
#       GridServiceSchedulerWorker picks up the deploy
#   - queued: created_at=T0 queued_at=T2
#       A different deploy is already running, so this deploy remains queued.
#       Deploy is picked up again by a different GridServiceSchedulerWorker
#   - ongoing: created_at=T0 queued_at=T2 started_at=T3
#       GridServiceDeployer was run by the GridServiceSchedulerWorker
#   - success: created_at=T0 queued_at=T2 started_at=T3 finished_at=T4
#       GridServiceDeployer has completed succesfully
#   - error: created_at=T0 queued_at=T2 started_at=T3 finished_at=T4
#       GridServiceDeployer has failed with an error
#   - abort: created_at=T0 queued_at=T2 started_at=T3? finished_at=T4
#       GridServiceSchedulerWorker has decided not to run the deploy
class GridServiceDeploy
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Enum

  field :queued_at, type: DateTime
  field :started_at, type: DateTime
  field :finished_at, type: DateTime
  field :reason, type: String
  enum :deploy_state, [:created, :queued, :ongoing, :success, :error, :abort], default: :created

  embeds_many :grid_service_instance_deploys

  index({ grid_service_id: 1 }, { background: true })
  index({ created_at: 1 }, { background: true })
  index({ queued_at: 1 }, { background: true })
  index({ started_at: 1 }, { background: true })

  belongs_to :grid_service
  belongs_to :stack_deploy

  # Finish deploy in aborted state.
  #
  # @param reason [String]
  def abort!(reason)
    self.set(:finished_at => Time.now.utc, :deploy_state => :abort, :reason => reason)
  end
end
