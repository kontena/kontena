require 'redis'

$redis = ConnectionPool.new(size: 20, timeout: 5) { Redis.new(url: ENV['REDIS_URL']) }
$redis_sub = ConnectionPool.new(size: 50, timeout: 5) { Redis.new(url: ENV['REDIS_URL']) }