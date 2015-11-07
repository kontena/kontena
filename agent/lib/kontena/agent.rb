module Kontena
  class Agent

    VERSION = File.read('./VERSION').strip

    def initialize(opts)
      @opts = opts

      @queue_worker = Kontena::QueueWorker.new
      @client = Kontena::WebsocketClient.new(@opts[:api_uri], @opts[:api_token])
      @node_info_worker = Kontena::NodeInfoWorker.new(@queue_worker.queue)
      @container_info_worker = Kontena::ContainerInfoWorker.new(@queue_worker.queue)
      @log_worker = Kontena::LogWorker.new(@queue_worker.queue)
      @weave_attacher = Kontena::WeaveAttacher.new
      @weave_adapter = Kontena::WeaveAdapter.new
      @event_worker = Kontena::EventWorker.new(@queue_worker.queue)
      @cadvisor_launcher = Kontena::CadvisorLauncher.new
      @stats_worker = Kontena::StatsWorker.new(@queue_worker.queue)
      @etcd_launcher = Kontena::EtcdLauncher.new
      @lb_registrator = Kontena::LoadBalancerRegistrator.new
    end

    def start!
      start_em

      @weave_attacher.start!
      @client.ensure_connect
      @node_info_worker.start!
      @container_info_worker.start!
      @log_worker.start!
      @event_worker.start!
      @cadvisor_launcher.start!
      @stats_worker.start!
      @weave_adapter.start!
      @etcd_launcher.start!
      @lb_registrator.start!
    end

    def start_em
      Thread.new { EventMachine.run } unless EventMachine.reactor_running?
      sleep 0.01 until EventMachine.reactor_running?
    end
  end
end
