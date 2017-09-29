require 'securerandom'

module Kontena
  module ServicePods
    class LifecycleHookManager
      include Kontena::Helpers::RpcHelper
      include Common

      attr_reader :node, :service_pod

      def initialize(node)
        @node = node
      end

      def track(service_pod)
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
            service_config['name'] = "#{service_config['name']}-#{SecureRandom.urlsafe_base64(5)}"
            service_container = create_container(service_config)
            log_hook_output(service_container.id, "running pre_start hook: #{hook['cmd']}", 'stdout')
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
          log_hook_output(service_container.id, "running post_start hook: #{hook['cmd']}", 'stdout')
          _, _, exit_code = service_container.exec(command) { |stream, chunk|
            log_hook_output(service_container.id, chunk, stream)
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

      # @param [Docker::Container] service_container
      # @return [Boolean]
      def on_pre_stop(service_container)
        hooks_for('pre_stop').each do |hook|
          info "running pre_stop hook: #{hook['cmd']}"
          command = build_cmd(hook['cmd'])
          log_hook_output(service_container.id, "running pre_stop hook: #{hook['cmd']}", 'stdout')
          _, _, exit_code = service_container.exec(command) { |stream, chunk|
            log_hook_output(service_container.id, chunk, stream)
          }
          if exit_code != 0
            raise "Failed to execute pre_stop hook: #{hook['cmd']} (exit code: #{exit_code}"
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
        hooks = service_pod.hooks.select { |h|
          h['type'] == type && !cached_oneshot_hook?(h)
        }
        hooks.each { |h|
          mark_oneshot_hook(h) if !cached_oneshot_hook?(h)
        }

        hooks
      end

      # @param hook [Hash]
      # @return [Boolean]
      def cached_oneshot_hook?(hook)
        hook['oneshot'] && oneshot_cache.include?(hook['id'])
      end

      # @param [String] cmd
      # @return [Array<String>]
      def build_cmd(cmd)
        command = ['/bin/sh', '-c', cmd]

        command
      end

      # @param service_pod [ServicePod]
      # @param cmd [String]
      # @return [Hash]
      def config_container(service_pod, cmd)
        service_pod.entrypoint = ['/bin/sh', '-c']
        service_pod.cmd = cmd
        service_config = super(service_pod)
        service_config['HostConfig'].delete('RestartPolicy')
        service_config['Labels']['io.kontena.container.type'] = 'service_hook'

        service_config
      end

      # @param [String] id
      # @param [String] line
      # @param [String] type
      def log_hook_output(id, line, type)
        data = [{
          id: id,
          time: Time.now.utc.xmlschema(6),
          type: type,
          data: line
        }]
        rpc_client.async.notification('/containers/log_batch', [data])
      end

      # @param [String] type
      # @param [String] data
      # @param [Integer] severity
      def log_service_pod_event(type, data, severity = Logger::INFO)
        super(service_pod.service_id, service_pod.instance_number, type, data, severity)
      end

      # @param hook [Hash]
      def mark_oneshot_hook(hook)
        return unless hook['oneshot']

        pod = {
          service_id: service_pod.service_id,
          instance_number: service_pod.instance_number
        }
        rpc_client.request('/node_service_pods/mark_oneshot_hook', [node.id, pod, hook])
        oneshot_cache << hook['id']
      end

      # @return [Array<Hash>]
      def oneshot_cache
        @oneshot_cache ||= Set.new
      end
    end
  end
end