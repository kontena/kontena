require_relative 'logging'

module Kontena
  class Agent
    include Logging

    VERSION = File.read('./VERSION').strip

    def initialize(opts)
      info "initializing agent (version #{VERSION})"
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

    def run!
      self_read, self_write = IO.pipe

      %w(TERM TTIN).each do |sig|
        trap sig do
          self_write.puts(sig)
        end
      end

      begin
        connect!

        while readable_io = IO.select([self_read])
          signal = readable_io.first[0].gets.strip
          handle_signal(signal)
        end
      rescue Interrupt
        exit(0)
      end
    end

    # @param [String] signal
    def handle_signal(signal)
      info "Got signal #{signal}"
      case signal
      when 'TERM'
        info "Shutting down..."
        EM.stop
        @supervisor.shutdown
        raise Interrupt
      when 'TTIN'
        Thread.list.each do |thread|
          warn "Thread #{thread.object_id.to_s(36)} #{thread['label']}"
          if thread.backtrace
            warn thread.backtrace.join("\n")
          else
            warn "no backtrace available"
          end
        end
      end
    end

    def supervise_launchers
      @supervisor.supervise(
        type: Kontena::Launchers::IpamPlugin,
        as: :ipam_plugin_launcher
      )
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
        type: Kontena::Workers::ImagePullWorker,
        as: :image_pull_worker
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
      @supervisor.supervise(
        type: Kontena::Workers::ContainerStarterWorker,
        as: :container_starter_worker
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
