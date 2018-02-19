class StackDeploy
  include Mongoid::Document
  include Mongoid::Timestamps

  field :error, type: String
  field :finished_at, type: DateTime

  index({ stack_id: 1 })

  belongs_to :stack
  has_many :grid_service_deploys, dependent: :destroy

  def error!(message)
    self.finished_at = Time.now
    self.error = message
    self.save!
  end

  # @return [DateTime]
  def started_at
    timestamps = self.grid_service_deploys.map{|service_deploy| service_deploy.started_at}

    timestamps.compact.min
  end

  # @return [DateTime]
  def finished_at
    return self.finished_at if self.finished_at

    timestamps = self.grid_service_deploys.map{|service_deploy| service_deploy.finished_at}

    return nil if timestamps.any? {|timestamp| !timestamp }

    timestamps.max
  end

  # @return [Boolean]
  def created?
    self.grid_service_deploys.empty?
  end

  # @return [Boolean]
  def error?
    return true if self.error
    
    self.grid_service_deploys.any? { |service_deploy| service_deploy.error? }
  end

  # @return [Boolean]
  def success?
    self.grid_service_deploys.all? { |service_deploy| service_deploy.success? }
  end

  # @return [Symbol]
  def state
    if error?
      :error
    elsif created?
      :created
    elsif success?
      :success
    else
      :ongoing
    end
  end
end
