module CurrentLeader

  # @return [Boolean]
  def leader?
    job = Celluloid::Actor[:leader_elector_job]
    if job
      job.leader?
    else
      false
    end
  end
end
