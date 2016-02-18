module Kontena
  class Agent

    VERSION = File.read('./VERSION').strip

    def initialize(opts)
      @opts = opts

      @queue_worker = Kontena::QueueWorker.new
      @client = Kontena::WebsocketClient.new(@opts[:api_uri], @opts[:api_token])
      @weave_attacher = Kontena::WeaveAttacher.new
      @weave_adapter = Kontena::WeaveAdapter.new
      @cadvisor_launcher = Kontena::CadvisorLauncher.new
      @etcd_launcher = Kontena::EtcdLauncher.new

      @started = false
      Pubsub.subscribe('agent:node_info') do |info|
        self.start(info)
      end
    end

    # Connect to master server
    def connect!
      start_em
      @client.ensure_connect
    end

    # @param [Hash] node_info
    def start(node_info)
      return if self.started?
      @started = true

      supervisor = Celluloid::Supervision::Container.run!
      supervisor.supervise(
        type: Kontena::Workers::LogWorker,
        as: :log_worker,
        args: [@queue_worker.queue]
      )
      supervisor.supervise(
        type: Kontena::Workers::NodeInfoWorker,
        as: :node_info_worker,
        args: [@queue_worker.queue]
      )
      supervisor.supervise(
        type: Kontena::Workers::ContainerInfoWorker,
        as: :container_info_worker,
        args: [@queue_worker.queue]
      )
      supervisor.supervise(
        type: Kontena::LoadBalancers::Configurer,
        as: :lb_configurer
      )
      supervisor.supervise(
        type: Kontena::LoadBalancers::Registrator,
        as: :lb_registrator
      )
      supervisor.supervise(
        type: Kontena::Workers::EventWorker,
        as: :event_worker,
        args: [@queue_worker.queue]
      )

      @weave_adapter.start(node_info).value
      @weave_attacher.start!
      @etcd_launcher.start(node_info).value

      @cadvisor_launcher.start.value
      supervisor.supervise(
        type: Kontena::Workers::StatsWorker,
        as: :stats_worker,
        args: [@queue_worker.queue]
      )
    rescue => exc
      puts exc.message
      puts exc.backtrace.join("\n")
    end

    # @return [Boolean]
    def started?
      @started == true
    end

    def start_em
      Thread.new { EventMachine.run } unless EventMachine.reactor_running?
      sleep 0.01 until EventMachine.reactor_running?
    end
  end
end
