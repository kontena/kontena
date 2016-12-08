EM.epoll

Thread.new { EventMachine.run } unless EventMachine.reactor_running?
sleep 0.01 until EventMachine.reactor_running?
