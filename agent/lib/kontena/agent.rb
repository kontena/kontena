module Kontena
  class Agent

    VERSION = File.read('./VERSION').strip

    def initialize(opts)
      @opts = opts
      @queue = Queue.new
      @client = Kontena::WebsocketClient.new(@opts[:api_uri], @opts[:api_token])
      @supervisor = Celluloid::Supervision::Container.run!
      self.supervise_launchers
      self.supervise_network_adapter
      self.supervise_lb
      self.supervise_workers
    end

    # Connect to master server
    def connect!
      start_em
      @client.ensure_connect
    end

    def supervise_launchers
      @supervisor.supervise(
        type: Kontena::Launchers::Cadvisor,
        as: :cadvisor_launcher
      )
      @supervisor.supervise(
        type: Kontena::Launchers::Etcd,
        as: :etcd_launcher
      )
    end

    def supervise_network_adapter
      @supervisor.supervise(
        type: Kontena::NetworkAdapters::Weave,
        as: :network_adapter
      )
    end

    def supervise_workers
      @supervisor.supervise(
        type: Kontena::Workers::QueueWorker,
        as: :queue_worker,
        args: [@client, @queue]
      )
      @supervisor.supervise(
        type: Kontena::Workers::LogWorker,
        as: :log_worker,
        args: [@queue]
      )
      @supervisor.supervise(
        type: Kontena::Workers::NodeInfoWorker,
        as: :node_info_worker,
        args: [@queue]
      )
      @supervisor.supervise(
        type: Kontena::Workers::ContainerInfoWorker,
        as: :container_info_worker,
        args: [@queue]
      )
      @supervisor.supervise(
        type: Kontena::Workers::EventWorker,
        as: :event_worker,
        args: [@queue]
      )
      @supervisor.supervise(
        type: Kontena::Workers::StatsWorker,
        as: :stats_worker,
        args: [@queue]
      )
      @supervisor.supervise(
        type: Kontena::Workers::WeaveWorker,
        as: :overlay_worker
      )
      @supervisor.supervise(
        type: Kontena::Workers::ImageCleanupWorker,
        as: :image_cleanup_worker
      )
      @supervisor.supervise(
        type: Kontena::Workers::HealthCheckWorker,
        as: :health_check_worker,
        args: [@queue]
      )
    end

    def supervise_lb
      @supervisor.supervise(
        type: Kontena::LoadBalancers::Configurer,
        as: :lb_configurer
      )
      @supervisor.supervise(
        type: Kontena::LoadBalancers::Registrator,
        as: :lb_registrator
      )
    end

    def start_em
      EM.epoll
      Thread.new { EventMachine.run } unless EventMachine.reactor_running?
      sleep 0.01 until EventMachine.reactor_running?
    end
  end
end
