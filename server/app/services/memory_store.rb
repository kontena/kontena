# Simple memory store for Rack::Attack throttling
class MemoryStore

  attr_reader :data

  def initialize
    @data = {}
  end

  def clear(_ = nil)
    @data = {}
  end

  def cleanup
    now = Time.now.utc.to_i
    data.delete_if do |_, val|
      val[:expires_at] && val[:expires_at] < now
    end
  end
  
  def delete(key)
    data[key] = nil
  end

  def read(key)
    val = data[key] || {}
    val[:val]
  end

  def increment(key, amount = 1, options = {})
    cleanup if rand(50) == 1

    if options[:expires_in]
      options[:expires_at] = Time.now.utc + options[:expires_in]
    end
    val = data[key] || {}
    val[:val] ||= 0
    if val[:expires_at].to_i > 0 && Time.now.utc.to_i > val[:expires_at].to_i
      val[:val] = 0
    end
    result = val[:val] + amount
    data[key] = { val: result, expires_at: options[:expires_at].to_i }
    result
  end

  def write(key, value, options = {})
    cleanup if rand(50) == 1

    if options[:expires_in]
      options[:expires_at] = Time.now.utc + options[:expires_in]
    end

    data[key] = { val: value, expires_at: options[:expires_at].to_i }
  end
end
