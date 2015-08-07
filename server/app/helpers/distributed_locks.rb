module DistributedLocks

  # @param [String] name
  # @param [Integer] timeout
  def with_dlock(name, timeout = 10)
    DistributedLock.with_lock(name, timeout) {
      yield
    }
  end
end