require_relative '../helpers/wait_helper'

class DistributedLock
  include Mongoid::Document

  field :name, type: String
  field :lock_id, type: String
  field :created_at, type: DateTime

  index({ name: 1 }, { unique: true })

  # @param [String] name
  # @param [Integer] timeout
  def self.with_lock(name, timeout = 60)
    lock_id = nil
    begin
      if timeout.to_f > 0.0
        lock_id = WaitHelper.wait_until("lock #{name} is available", timeout: timeout, interval: 0.05) { self.obtain_lock(name) }
      else
        lock_id = self.obtain_lock(name)
      end

      if lock_id
        return yield
      else
        return false
      end
    ensure
      self.release_lock(name, lock_id) if lock_id
    end
  end

  # @param [String] name
  # @return [String, FalseClass]
  def self.obtain_lock(name)
    lock_id = SecureRandom.hex(16)
    query = {name: name, lock_id: {:$exists => false}}
    modify = {'$set' => {name: name, lock_id: lock_id, created_at: Time.now.utc}}
    lock = nil
    begin
      lock = where(query).find_one_and_update(modify, {upsert: true, return_document: :after})
    rescue Mongo::Error::OperationFailure
    end
    if lock && lock.lock_id == lock_id
      lock_id
    else
      false
    end
  end

  # @param [String] name
  # @param [String] lock_id
  def self.release_lock(name, lock_id)
    where(name: name, lock_id: lock_id).destroy
  end
end
