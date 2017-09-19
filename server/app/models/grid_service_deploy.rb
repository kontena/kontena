# States:
#   - created pending: created_at=T0
#       GridServices::Deploy request, or some internal scheduler, decides to deploy the service
#   - created pending: created_at=T0 queued_at=T1
#       GridServiceSchedulerWorker picks up the deploy
#   - created pending: created_at=T0 queued_at=T2
#       A different deploy is already running, so this deploy remains queued.
#       Deploy is picked up again by a different GridServiceSchedulerWorker
#   - created aborted: created_at=T0 queued_at=T2 finished_at=T3
#       GridServiceSchedulerWorker has decided not to run the deploy, such as if the service was stopped.
#   - ongoing started running: created_at=T0 queued_at=T2 started_at=T3
#       GridServiceDeployer was run by the GridServiceSchedulerWorker
#   - success finished done: created_at=T0 queued_at=T2 started_at=T3 finished_at=T4
#       GridServiceDeployer has completed succesfully
#   - error finished done: created_at=T0 queued_at=T2 started_at=T3 finished_at=T4
#       GridServiceDeployer has failed with an error
class GridServiceDeploy
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Enum

  # deploy times out if running for more than 30 minutes
  TIMEOUT = 30.minutes

  field :queued_at, type: DateTime
  field :started_at, type: DateTime
  field :finished_at, type: DateTime
  field :reason, type: String
  enum :deploy_state, [:created, :ongoing, :success, :error], default: :created

  embeds_many :grid_service_instance_deploys

  has_many :grid_domain_authorizations # Possibility to handle multiple tls-sni cert updates in one deploy

  index({ grid_service_id: 1 }, { background: true })
  index({ created_at: 1 }, { background: true })
  index({ queued_at: 1 }, { background: true })
  index({ started_at: 1 }, { background: true })

  belongs_to :grid_service
  belongs_to :stack_deploy

  scope :deploying, -> { any_of({:started_at => nil, :finished_at => nil}, {:started_at.gt => TIMEOUT.ago , finished_at: nil}) }
  scope :pending, -> { where(:started_at => nil, :finished_at => nil) }
  scope :running, -> { where(:started_at.ne => nil).where(:started_at.gt => TIMEOUT.ago, :finished_at => nil) }

  # @return [Boolean]
  def queued?
    !!queued_at
  end

  # @return [Boolean]
  def pending?
    !started? && !finished?
  end

  # @return [Boolean]
  def started?
    !!started_at
  end

  # @return [Boolean]
  def timeout?
    started_at <= TIMEOUT.ago && !finished?
  end

  # @return [Boolean]
  def running?
    started? && !finished? && !timeout?
  end

  # @return [Boolean]
  def finished?
    !!finished_at
  end

  # Deploy has been running, and is now finished.
  #
  # @return [Boolean]
  def done?
    started? && finished?
  end

  # Deploy was finished without being running.
  #
  # @return [Boolean]
  def aborted?
    !started? && finished?
  end

  # Finish deploy without it necessarily being running, setting an error state.
  #
  # @param reason [String]
  def abort!(reason = nil)
    self.set(:finished_at => Time.now.utc, :_deploy_state => :error, :reason => reason)
  end
end
