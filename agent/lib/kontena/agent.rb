module Kontena
  class Agent

    def initialize(opts)
      @opts = opts

      @queue_worker = Kontena::QueueWorker.new
      @client = Kontena::WebsocketClient.new(@opts[:api_uri], @opts[:api_token])
      @container_info_worker = Kontena::ContainerInfoWorker.new(@queue_worker.queue)
      @log_worker = Kontena::LogWorker.new(@queue_worker.queue)
      @weave_attacher = Kontena::WeaveAttacher.new
      @event_worker = Kontena::EventWorker.new(@queue_worker.queue)
      @stats_worker = Kontena::StatsWorker.new(@opts[:cadvisor_url], @queue_worker.queue)
    end

    def start!
      start_em

      @weave_attacher.start!
      @client.connect
      @container_info_worker.start!
      @log_worker.start!
      @event_worker.start!
      @stats_worker.start!
    end

    def start_em
      Thread.new { EventMachine.run } unless EventMachine.reactor_running?
      sleep 0.01 until EventMachine.reactor_running?
    end
  end
end
