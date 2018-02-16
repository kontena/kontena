require 'logger'
require 'net/http'
require 'thread'
require 'thwait'

def getenv(name, default = nil, &block)
  if (value = ENV[name]) && !value.empty?
    value = yield value if block
    value
  elsif default
    default
  else
    fail "Missinsg ENV #{name}"
  end
end

URL = getenv('URL') { |v| URI(v) }
THREADS = getenv('THREADS', 8) { |v| Integer(v) }
SKEW = getenv('SKEW', 1.0) { |v| Float(v)}

$logger = Logger.new($stderr)
$logger.progname = ARGV[0]

def time
  t = Time.now
  r = yield
  return Time.now - t, r
end

def client_thread(i)
  $logger.info "Start #{i}/#{THREADS}..."

  loop do
    sleep rand() * SKEW

    latency, response = time { Net::HTTP.get_response(URL) }

    $logger.info "[thread #{'%2d' % i}/#{THREADS}] GET #{URL} => HTTP #{response.code} in #{'%.3fs' % latency}: #{response.body.strip}"

    response.value # raises
  end
end

threads = (1..THREADS).map { |i|
  thread = Thread.new do
    begin
      client_thread(i)
    rescue => exc
      $logger.error exc
      raise
    end
  end
}

$logger.info "Waiting for #{threads.size} threads..."

threads_wait = ThreadsWait.new(*threads)
thread = threads_wait.next_wait
thread.value # raises
