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

        pre_pod = service_pod.dup
        pre_pod.entrypoint = '/bin/sh'
        pre_pod.cmd = ['-c', 'sleep 600']
        service_config = config_container(pre_pod)
        service_container = create_container(service_config)
        service_container.start!
        pre_start_hooks.each do |hook|
          info "running pre_start hook: #{hook['cmd']}"
          command = ['/w/w', '/bin/sh', '-c', hook['cmd']]
          log_hook_output(service_container.id, ["running pre_start hook: #{hook['cmd']}"], 'stdout')
          _, _, exit_code = service_container.exec(command) { |stream, chunk|
            log_hook_output(service_container.id, [chunk], stream)
          }
          if exit_code != 0
            raise "Failed to execute pre_start hook: #{hook['cmd']} (exit code: #{exit_code}"
          end
        end
        true
      rescue => exc
        log_service_pod_event("service:create_instance", exc.message, Logger::ERROR)
        raise exc
      ensure
        cleanup_container(service_container) if service_container
      end

      # @param [Docker::Container] service_container
      # @return [Boolean]
      def on_post_start(service_container)
        hooks_for('post_start').each do |hook|
          info "running post_start hook: #{hook['cmd']}"
          command = ['/w/w', '/bin/sh', '-c', hook['cmd']]
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