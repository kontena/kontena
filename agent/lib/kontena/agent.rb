require 'singleton'
require_relative 'logging'

module Kontena
  class Agent
    include Singleton
    include Logging

    NODE_ID_REGEXP = /\A[A-Z0-9]{4}(:[A-Z0-9]{4}){11}\z/
    VERSION = File.read('./VERSION').strip

    # Called from other actors
    def self.shutdown
      instance.write_signal('shutdown')
    end

    def initialize
      info "initializing agent (version #{VERSION})"

      @read_pipe, @write_pipe = IO.pipe
    end

    def docker_info
      @docker_info ||= Docker.info
    end

    def configure(opts)
      @opts = opts

      if node_id = opts[:node_id]
        raise ArgumentError, "Invalid KONTENA_NODE_ID: #{node_id}" unless node_id.match(NODE_ID_REGEXP)

        @node_id = node_id
      else
        @node_id = docker_info['ID']
      end

      if node_name = opts[:node_name]
        raise ArgumentError, "Invalid KONTENA_NODE_NAME: #{node_name}" if node_name.empty?
        @node_name = node_name
      else
        @node_name = docker_info['Name']
      end

      if node_labels = opts[:node_labels]
        @node_labels = node_labels.split()
      else
        @node_labels = docker_info['Labels'].to_a
      end
    end

    # @return [String]
    def node_name
      @node_name
    end

    # @return [String]
    def node_id
      @node_id
    end

    # @return [Array<String>]
    def node_labels
      @node_labels
    end

    def ssl_verify?
      return false if @opts[:ssl_verify].nil?
      return false if @opts[:ssl_verify].empty?
      return true
    end

    def ssl_params
      {
        verify_mode: self.ssl_verify? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE,
      }
    end

    def ssl_hostname
      @opts[:ssl_hostname]
    end

    def write_signal(sig)
      @write_pipe.puts(sig)
    end

    def run!
      trap 'TERM' do
        write_signal('shutdown')
      end
      trap 'TTIN' do
        write_signal('trace')
      end

      self.supervise

      while line = @read_pipe.gets
        handle_signal line.strip
      end
    rescue Interrupt
      exit(0)
    end

    # @param [String] signal
    def handle_signal(signal)
      info "Got signal #{signal}"
      case signal
      when 'shutdown'
        self.handle_shutdown
      when 'trace'
        self.handle_trace
      end
    end

    def handle_shutdown
      info "Shutting down..."
      @supervisor.shutdown # shutdown all actors
      @write_pipe.close # let run! break and return
    end

    def handle_trace
      info "Dump celluloid actor and thread stacks..."

      Celluloid.dump

      Thread.list.each do |thread|
        next if thread[:celluloid_actor_system]

        puts "Thread 0x#{thread.object_id.to_s(16)} <#{thread.name}>"
        if backtrace = thread.backtrace
          puts "\t#{backtrace.join("\n\t")}"
        end
        puts
      end

      info "Dump cellulooid actor and thread stacks: done"
    end

    def supervise
      @supervisor = Celluloid::Supervision::Container.run!

      self.supervise_state
      self.supervise_rpc
      self.supervise_launchers
      self.supervise_network_adapter
      self.supervise_lb
      self.supervise_workers
    end

    def supervise_state
      @supervisor.supervise(
        type: Kontena::Observable::Registry,
        as: :observable_registry,
      )
      @supervisor.supervise(
        type: Kontena::Workers::NodeInfoWorker,
        as: :node_info_worker,
        args: [self.node_id,
          node_name: self.node_name,
        ],
      )
    end

    def supervise_rpc
      @supervisor.supervise(
        type: Kontena::RpcServer,
        as: :rpc_server,
      )
      @supervisor.supervise(
        type: Kontena::RpcClient,
        as: :rpc_client,
      )
      @supervisor.supervise(
        type: Kontena::WebsocketClient,
        as: :websocket_client,
        args: [@opts[:api_uri], @node_id,
          node_name: self.node_name,
          grid_token: @opts[:grid_token],
          node_token: @opts[:node_token],
          node_labels: @node_labels,
          ssl_params: self.ssl_params,
          ssl_hostname: self.ssl_hostname,
        ],
      )
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
        type: Kontena::Workers::ImagePullWorker,
        as: :image_pull_worker
      )
      @supervisor.supervise(
        type: Kontena::Workers::LogWorker,
        as: :log_worker
      )
      @supervisor.supervise(
        type: Kontena::Workers::ContainerInfoWorker,
        as: :container_info_worker,
        args: [@node_id],
      )
      @supervisor.supervise(
        type: Kontena::Workers::EventWorker,
        as: :event_worker
      )
      @supervisor.supervise(
        type: Kontena::Workers::NodeStatsWorker,
        as: :node_stats_worker
      )
      @supervisor.supervise(
        type: Kontena::Workers::StatsWorker,
        as: :stats_worker
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
        as: :health_check_worker
      )
      @supervisor.supervise(
        type: Kontena::Workers::FluentdWorker,
        as: :fluentd_worker
      )
      @supervisor.supervise(
        type: Kontena::Workers::ServicePodManager,
        as: :service_pod_manager
      )
      @supervisor.supervise(
        type: Kontena::Workers::Volumes::VolumeManager,
        as: :volume_manager
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
  end
end
