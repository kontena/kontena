require_relative 'services_helper'

module Kontena::Cli::Services
  class UpdateCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"

    option "--image", "IMAGE", "Docker image to use"
    option ["-p", "--ports"], "PORT", "Publish a service's port to the host", multivalued: true
    option ["-e", "--env"], "ENV", "Set environment variables", multivalued: true
    option ["-l", "--link"], "LINK", "Add link to another service in the form of name:alias", multivalued: true
    option ["-a", "--affinity"], "AFFINITY", "Set service affinity", multivalued: true
    option ["-c", "--cpu-shares"], "CPU_SHARES", "CPU shares (relative weight)"
    option ["-m", "--memory"], "MEMORY", "Memory limit (format: <number><optional unit>, where unit = b, k, m or g)"
    option ["--memory-swap"], "MEMORY_SWAP", "Total memory usage (memory + swap), set \'-1\' to disable swap (format: <number><optional unit>, where unit = b, k, m or g)"
    option "--cmd", "CMD", "Command to execute"
    option "--instances", "INSTANCES", "How many instances should be deployed"
    option ["-u", "--user"], "USER", "Username who executes first process inside container"
    option "--privileged", :flag, "Give extended privileges to this service", default: false
    option "--cap-add", "CAP_ADD", "Add capabitilies", multivalued: true, default: nil
    option "--cap-drop", "CAP_DROP", "Drop capabitilies", multivalued: true, default: nil
    option "--net", "NET", "Network mode"
    option "--log-driver", "LOG_DRIVER", "Set logging driver"
    option "--log-opt", "LOG_OPT", "Add logging options", multivalued: true, default: nil
    option "--deploy-strategy", "STRATEGY", "Deploy strategy to use (ha, daemon, random)"
    option "--deploy-wait-for-port", "PORT", "Wait for port to respond when deploying"
    option "--deploy-min-health", "FLOAT", "The minimum percentage (0.0 - 1.0) of healthy instances that do not sacrifice overall service availability while deploying"
    option "--deploy-interval", "TIME", "Auto-deploy with given interval (format: <number><unit>, where unit = min, h, d)"
    option "--pid", "PID", "Pid namespace to use"
    option "--secret", "SECRET", "Import secret from Vault (format: <secret>:<name>:<type>)", multivalued: true
    option "--health-check-uri", "HEALTH CHECK URI", "URI path for HTTP health check"
    option "--health-check-timeout", "HEALTH CHECK TIMEOUT", "Timeout for HTTP health check"
    option "--health-check-interval", "HEALTH CHECK INTERVAL", "Interval for HTTP health check"
    option "--health-check-initial-delay", "HEALTH CHECK INITIAL DELAY", "Initial for HTTP health check"
    option "--health-check-port", "HEALTH CHECK PORT", "Port for HTTP health check"
    option "--health-check-protocol", "HEALTH CHECK PROTOCOL", "Protocol of health check"

    def execute
      require_api_url
      token = require_token

      data = parse_service_data_from_options
      update_service(token, name, data)
    end

    ##
    # parse given options to hash
    # @return [Hash]
    def parse_service_data_from_options
      data = {}
      data[:strategy] = deploy_strategy if deploy_strategy
      data[:ports] = parse_ports(ports_list) unless ports_list.empty?
      data[:links] = parse_links(link_list) unless link_list.empty?
      data[:memory] = parse_memory(memory) if memory
      data[:memory_swap] = parse_memory(memory_swap) if memory_swap
      data[:cpu_shares] = cpu_shares if cpu_shares
      data[:affinity] = affinity_list unless affinity_list.empty?
      data[:env] = env_list unless env_list.empty?
      data[:secrets] = parse_secrets(secret_list) unless secret_list.empty?
      data[:container_count] = instances if instances
      data[:cmd] = cmd.split(" ") if cmd
      data[:user] = user if user
      data[:image] = parse_image(image) if image
      data[:privileged] = privileged?
      data[:cap_add] = cap_add_list if cap_add_list
      data[:cap_drop] = cap_drop_list if cap_drop_list
      data[:net] = net if net
      data[:log_driver] = log_driver if log_driver
      data[:log_opts] = parse_log_opts(log_opt_list) if log_opt_list
      data[:deploy_opts] = {}
      data[:deploy_opts][:min_health] = deploy_min_health.to_f if deploy_min_health
      data[:deploy_opts][:wait_for_port] = deploy_wait_for_port.to_i if deploy_wait_for_port
      if deploy_interval
        data[:deploy_opts][:interval] = parse_relative_time(deploy_interval)
      end
      if health_check_port
        data[:health_check] = { 
          protocol: health_check_protocol,
          uri: health_check_uri, 
          port: health_check_port, 
          timeout: health_check_timeout, 
          interval: health_check_interval,
          initial_delay: health_check_initial_delay
        }
      end
      data.delete(:deploy_opts) if data[:deploy_opts].empty?
      data[:pid] = pid if pid
      data
    end
  end
end
