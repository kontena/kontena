require_relative '../logging'
require_relative '../helpers/iface_helper'
require_relative '../helpers/wait_helper'
require_relative '../helpers/weave_helper'

module Kontena::NetworkAdapters
  # Configure containers and manage the overlay IPAM
  # Per-container attaching happens in the Kontena::Workers::WeaveWorker
  class Weave
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Helpers::IfaceHelper
    include Kontena::Helpers::WeaveHelper
    include Kontena::Helpers::WaitHelper
    include Kontena::Logging
    include Kontena::Observer

    DEFAULT_NETWORK = 'kontena'.freeze

    def initialize(start: true)
      @started = false

      info 'initialized'

      async.start if start
    end

    # @return [IpamClient]
    def ipam_client
      @ipam_client ||= IpamClient.new

      # XXX: just retry requests instead
      wait_until!("IPAM is ready") { @ipam_client.activate? }

      @ipam_client
    end

    # XXX: exclusive!
    # @param node [Node]
    def update(node)
      state = self.ensure(node)

      update_observable(state)

    rescue => exc
      error exc

      reset_observable
    end

    # Wait until ready
    # @raise [Timeout::Error]
    def wait!
      wait_until!("weave started") { @started }
    end

    def start
      self.ensure_weavewait

      observe(Actor[:node_info_worker], Actor[:weave_launcher], Actor[:ipam_plugin_launcher]) do |node, weave, ipam|
        # only once
        unless @started
          @default_ipam_pool = self.ensure_default_pool(node.grid_subnet)
          @started = true
        end
      end
    end

    # @param grid_subnet [IPAddress]
    def ensure_default_pool(grid_subnet)
      lower, upper = grid_subnet.split(2)

      info "Ensuring default entwork IPAM pool=#{DEFAULT_NETWORK} with subnet=#{grid_subnet.to_string} iprange=#{upper.to_string}"

      ipam_client.reserve_pool(DEFAULT_NETWORK, grid_subnet.to_string, upper.to_string)
    end

    # @return [String]
    def default_ipam_pool_id
      @default_ipam_pool['PoolID']
    end

    # IP of local weave DNS resolver
    #
    # @return [String]
    def weave_dns_ip
      # always listens on the docker0 IP
      @weave_dns_ip ||= interface_ip('docker0') # XXX: fail on errors?
    end

    # Modify container create options to use weavewait + reserve overlay network address for later attach.
    #
    # Called from Kontena::ServicePods::Creator.
    #
    # @param opts [Hash] container create options
    # @return [Hash]
    def modify_container_opts(opts)
      wait!

      container_image = inspect_container_image(opts)
      entrypoint, cmd = build_container_entrypoint(opts, container_image)
      overlay_network, overlay_cidr = reserve_container_address(opts)
      dns_ip = self.weave_dns_ip

      host_config = opts['HostConfig'] ||= {}
      host_config['VolumesFrom'] ||= []
      host_config['VolumesFrom'] << "#{weavewait_name}:ro"
      host_config['Dns'] = [dns_ip] if dns_ip && host_config['NetworkMode'].to_s != 'host'

      labels = opts['Labels'] ||= {}
      labels['io.kontena.container.overlay_network'] = overlay_network
      labels['io.kontena.container.overlay_cidr'] = overlay_cidr

      opts
    end

    # Lookup Docker image used for container.
    #
    # @param opts [Hash] container create options
    def inspect_container_image(opts)
      image = Docker::Image.get(opts['Image'])
    end

    # Wrap container entrypoint/command to use the weavewait entrypoint, based on image config.
    #
    # @param opts [Hash] container create options
    # @param image [Docker::Image]
    # @param entrypoint [Array<String>]
    # @return [String, String] entrypoint, cmd
    def build_container_entrypoint(opts, image, entrypoint = '/w/w')
      image_config = image.info['Config']

      cmd = []
      if opts['Entrypoint']
        if opts['Entrypoint'].is_a?(Array)
          cmd = cmd + opts['Entrypoint']
        else
          cmd = cmd + [opts['Entrypoint']]
        end
      end
      if !opts['Entrypoint'] && image_config['Entrypoint'] && image_config['Entrypoint'].size > 0
        cmd = cmd + image_config['Entrypoint']
      end
      if opts['Cmd'] && opts['Cmd'].size > 0
        if opts['Cmd'].is_a?(Array)
          cmd = cmd + opts['Cmd']
        else
          cmd = cmd + [opts['Cmd']]
        end
      elsif image_config['Cmd'] && image_config['Cmd'].size > 0
        cmd = cmd + image_config['Cmd']
      end

      return entrypoint, cmd
    end

    # @param opts [Hash] container create options
    # @return [String, String] overlay network, cidr
    def reserve_container_address(opts)
      name = opts['name']
      overlay_network = self.default_ipam_pool_id
      overlay_cidr = @ipam_client.reserve_address(overlay_network)

      info "Reserve address for container=#{name} in pool=#{overlay_network}: #{overlay_cidr}"

      return overlay_network, overlay_cidr
    end

    # Release container overlay network address from IPAM.
    # Called by Kontena::Workers::WeaveWorker
    #
    # @param container_id [String] may not exist anymore
    # @param pool [String] IPAM pool ID from io.kontena.container.overlay_network
    # @param cidr [String] IPAM overlay CIDR from io.kontena.container.overlay_cidr
    def release_container_address(container_id, pool, cidr)
      wait!

      info "Release address for container=#{container_id} in pool=#{pool}: #{cidr}"

      ipam_client.release_address(pool, cidr)
    rescue IpamError => error
      # Cleanup will take care of these later on
      warn "Failed to release address for container=#{container_id} in pool=#{pool} at cidr=#{cidr}: #{error}"
    end

# private
    def weavewait_name
      "weavewait-#{WEAVE_VERSION}"
    end

    # @raise [Docker::Error]
    # @return [Docker::Container] nil if not found
    def inspect_weavewait
      Docker::Container.get(weavewait_name)
    rescue Docker::Error::NotFoundError
      nil
    end

    # @raise [Docker::Error]
    def ensure_weavewait
      unless container = inspect_weavewait
        container = Docker::Container.create(
          'name' => weavewait_name,
          'Image' => weaveexec_image,
          'Entrypoint' => ['/bin/false'],
          'Labels' => {
            'weavevolumes' => ''
          },
          'Volumes' => {
            '/w' => {},
            '/w-noop' => {},
            '/w-nomcast' => {}
          }
        )
      end
    end
  end
end
