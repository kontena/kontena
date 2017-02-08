EM.epoll

if EventMachine.reactor_running?
  # Fail if some require'd library (such as faye-websocket) has already started EM without exception handling
  abort "EventMachine is already running, refusing to start"
else
  # Run EventMachine, and abort on exceptions
  Thread.new {
    Thread.current.abort_on_exception = true
    EventMachine.run
  }
  sleep 0.01 until EventMachine.reactor_running?
end
