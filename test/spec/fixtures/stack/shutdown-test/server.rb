require 'logger'
require 'socket'
require 'webrick'

NAME = Socket.gethostname
PORT = 8000
STATUS = 200
SHUTDOWN = !!ENV['SHUTDOWN']
TRAP = !!ENV['TRAP']
REQUEST_DELAY = ENV['REQUEST_DELAY'].to_f

$logger = Logger.new($stderr)
$logger.progname = ARGV[0]

server = WEBrick::HTTPServer.new(
    :Port => PORT,
)
server.mount_proc '/' do |req, res|
    q = req.query()

    status = STATUS
    status = q['status'].to_i if q['status']
    delay = REQUEST_DELAY

    sleep delay

    res.status = status
    res.body = "Response from #{NAME} (delay=#{'%.3fs' % delay})\n"
end

if TRAP
  trap 'TERM' do
    if SHUTDOWN
      $stderr.puts "shutdown on SIGTERM with #{server.tokens.max - server.tokens.size} active clients"
      server.shutdown # closes listeners after stopping
    else
      $stderr.puts "skip SIGTERM!"
    end
  end
end

$logger.info "start :#{PORT}"
server.start
