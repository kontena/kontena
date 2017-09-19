require_relative 'services_helper'
require 'shellwords'

module Kontena::Cli::Services
  class CreateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"
    parameter "IMAGE", "Service image (example: redis:3.0)"

    option ["-p", "--ports"], "PORTS", "Publish a service's port to the host", multivalued: true
    option ["-e", "--env"], "ENV", "Set environment variables", multivalued: true
    option ["-l", "--link"], "LINK", "Add link to another service in the form of name:alias", multivalued: true
    option ["-v", "--volume"], "VOLUME", "Add a volume or bind mount it from the host", multivalued: true
    option "--volumes-from", "VOLUMES_FROM", "Mount volumes from another container", multivalued: true
    option ["-a", "--affinity"], "AFFINITY", "Set service affinity", multivalued: true
    option "--cpus", "CPUS", "Number of CPUs" do |cpus|
      Float(cpus)
    end
    option ["-c", "--cpu-shares"], "CPU_SHARES", "CPU shares (relative weight)"
    option ["-m", "--memory"], "MEMORY", "Memory limit (format: <number><optional unit>, where unit = b, k, m or g)"
    option ["--memory-swap"], "MEMORY_SWAP", "Total memory usage (memory + swap), set \'-1\' to disable swap (format: <number><optional unit>, where unit = b, k, m or g)"
    option ["--shm-size"], "SHM_SIZE", "Size of /dev/shm (format: <number><optional unit>, where unit = b, k, m or g)"
    option "--cmd", "CMD", "Command to execute"
    option "--instances", "INSTANCES", "How many instances should be deployed"
    option ["-u", "--user"], "USER", "Username who executes first process inside container"
    option "--stateful", :flag, "Set service as stateful", default: false
    option "--privileged", :flag, "Give extended privileges to this service", default: false
    option "--cap-add", "CAP_ADD", "Add capabitilies", multivalued: true
    option "--cap-drop", "CAP_DROP", "Drop capabitilies", multivalued: true
    option "--net", "NET", "Network mode"
    option "--log-driver", "LOG_DRIVER", "Set logging driver"
    option "--log-opt", "LOG_OPT", "Add logging options", multivalued: true
    option "--deploy-strategy", "STRATEGY", "Deploy strategy to use (ha, daemon, random)"
    option "--deploy-wait-for-port", "PORT", "Wait for port to respond when deploying"
    option "--deploy-min-health", "FLOAT", "The minimum percentage (0.0 - 1.0) of healthy instances that do not sacrifice overall service availability while deploying"
    option "--deploy-interval", "TIME", "Auto-deploy with given interval (format: <number><unit>, where unit = min, h, d)"
    option "--pid", "PID", "Pid namespace to use"
    option "--secret", "SECRET", "Import secret from Vault (format: <secret>:<name>:<env>)", multivalued: true
    option "--health-check-uri", "URI", "URI path for HTTP health check"
    option "--health-check-timeout", "TIMEOUT", "Timeout for health check"
    option "--health-check-interval", "INTERVAL", "Interval for health check"
    option "--health-check-initial-delay", "DELAY", "Initial delay for health check"
    option "--health-check-port", "PORT", "Port for health check"
    option "--health-check-protocol", "PROTOCOL", "Protocol of health check"
    option "--stop-timeout", "STOP_TIMEOUT", "Timeout (duration) to stop a container"
    option "--read-only", :flag, "Read-only root fs for the container", default: false

    def execute
      require_api_url
      token = require_token
      data = {
        name: name,
        image: image,
        stateful: stateful?
      }
      data.merge!(parse_service_data_from_options)
      spinner "Creating #{name.colorize(:cyan)} service " do
        create_service(token, current_grid, data)
      end
    end

    ##
    # parse given options to hash
    # @return [Hash]
    def parse_service_data_from_options
      data = {}
      data[:ports] = parse_ports(ports_list) unless ports_list.empty?
      data[:links] = parse_links(link_list) unless link_list.empty?
      data[:volumes] = volume_list unless volume_list.empty?
      data[:volumes_from] = volumes_from_list unless volumes_from_list.empty?
      data[:memory] = parse_memory(memory) if memory
      data[:memory_swap] = parse_memory(memory_swap) if memory_swap
      data[:shm_size] = parse_memory(shm_size) if shm_size
      data[:cpus] = cpus if cpus
      data[:cpu_shares] = cpu_shares if cpu_shares
      data[:affinity] = affinity_list unless affinity_list.empty?
      data[:env] = env_list unless env_list.empty?
      data[:secrets] = parse_secrets(secret_list)
      data[:container_count] = instances if instances
      data[:cmd] = Shellwords.split(cmd) if cmd
      data[:user] = user if user
      data[:image] = parse_image(image) if image
      data[:privileged] = privileged?
      data[:cap_add] = cap_add_list unless cap_add_list.empty?
      data[:cap_drop] = cap_drop_list unless cap_drop_list.empty?
      data[:net] = net if net
      data[:log_driver] = log_driver if log_driver
      data[:log_opts] = parse_log_opts(log_opt_list)
      data[:strategy] = deploy_strategy if deploy_strategy
      deploy_opts = parse_deploy_opts
      data[:deploy_opts] = deploy_opts unless deploy_opts.empty?
      health_check = parse_health_check
      data[:health_check] = health_check unless health_check.empty?
      data[:pid] = pid if pid
      data[:stop_grace_period] = stop_timeout if stop_timeout
      data[:read_only] = read_only?
      data
    end
  end
end
