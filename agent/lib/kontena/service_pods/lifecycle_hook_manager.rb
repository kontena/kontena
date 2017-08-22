module Kontena
  module ServicePods
    class LifecycleHookManager
      include Kontena::Helpers::RpcHelper
      include Common

      attr_reader :service_pod

      # @param [ServicePod] service_pod
      def initialize(service_pod)
        @service_pod = service_pod
      end

      # @return [Boolean]
      def on_pre_start
        pre_start_hooks = hooks_for('pre_start')
        return if pre_start_hooks.size == 0

        pre_start_hooks.each do |hook|
          begin
            info "running pre_start hook: #{hook['cmd']}"
            service_config = config_container(service_pod.dup, hook['cmd'])
            service_container = create_container(service_config)
            service_container.tap(&:start).attach
            if service_container.state['ExitCode'] != 0
              raise "Failed to execute pre_start hook: #{hook['cmd']}, exit code: #{service_container.state['ExitCode']}"
            end
          ensure
            cleanup_container(service_container) if service_container
          end
        end
        true
      rescue => exc
        log_service_pod_event("service:create_instance", exc.message, Logger::ERROR)
        raise exc
      end

      # @param [Docker::Container] service_container
      # @return [Boolean]
      def on_post_start(service_container)
        hooks_for('post_start').each do |hook|
          info "running post_start hook: #{hook['cmd']}"
          command = build_cmd(hook['cmd'])
          log_hook_output(service_container.id, ["running post_start hook: #{hook['cmd']}"], 'stdout')
          _, _, exit_code = service_container.exec(command) { |stream, chunk|
            log_hook_output(service_container.id, [chunk], stream)
          }
          if exit_code != 0
            raise "Failed to execute post_start hook: #{hook['cmd']} (exit code: #{exit_code}"
          end
        end
        true
      rescue => exc
        log_service_pod_event("service:create_instance", exc.message, Logger::ERROR)
        error exc.message
        false
      end

      # @param [String] type
      # @return [Array<Hash>]
      def hooks_for(type)
        service_pod.hooks.select{ |h| h['type'] == type }
      end

      # @param [String] cmd
      # @return [Array<String>]
      def build_cmd(cmd)
        command = ['/bin/sh', '-c', cmd]
        command.unshift('/w/w') if service_pod.can_expose_ports?

        command
      end

      # @param [Hash] service_config
      # @param [String] cmd
      # @return [Hash]
      def config_container(service_config, cmd)
        service_config = super(service_config)
        service_config['HostConfig'].delete('RestartPolicy')
        service_config['Labels']['io.kontena.container.type'] = 'service_hook'
        service_config['Cmd'] = build_cmd(cmd)

        service_config
      end

      # @param [String] id
      # @param [Array<String>] lines
      # @param [String] type
      def log_hook_output(id, lines, type)
        lines.each do |chunk|
          data = {
              id: id,
              time: Time.now.utc.xmlschema,
              type: type,
              data: chunk
          }
          rpc_client.async.notification('/containers/log', [data])
        end
      end

      # @param [String] type
      # @param [String] data
      # @param [Integer] severity
      def log_service_pod_event(type, data, severity = Logger::INFO)
        super(service_pod.service_id, service_pod.instance_number, type, data, severity)
      end
    end
  end
end