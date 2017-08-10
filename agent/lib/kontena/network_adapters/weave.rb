require_relative '../helpers/iface_helper'
require_relative '../helpers/launcher_helper'
require_relative '../helpers/weave_helper'

module Kontena::NetworkAdapters
  # Configure containers for use with weave.
  # Manages the default IPAM pool, and allocates addresses for contaienrs.
  # The actual container runtime attach happens in the Kontena::Workers::WeaveWorker.
  class Weave
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Helpers::IfaceHelper
    include Kontena::Helpers::LauncherHelper
    include Kontena::Helpers::WeaveHelper
    include Kontena::Logging
    include Kontena::Observer
    include Kontena::Observable

    WEAVEWAIT_NAME = "weavewait-#{WEAVE_VERSION}"
    DEFAULT_NETWORK = 'kontena'.freeze

    def initialize(start: true)
      info 'initialized'

      async.start if start
    end

    # @return [Kontena::NetworkAdapters::IpamClient]
    def ipam_client
      @ipam_client ||= IpamClient.new
    end

    def start
      self.ensure_weavewait

      observe(Actor[:node_info_worker], Actor[:weave_launcher], Actor[:ipam_plugin_launcher]) do |node, weave, ipam|
        update(node) unless updated? # only once
      end
    end

    # @return [Boolean]
    def updated?
      !!@updated
    end

    # @param node [Node]
    def update(node)
      state = self.ensure(node)

      update_observable(state)

      @updated = true

    rescue => exc
      @updated = false

      error exc

      reset_observable
    end

    # @param node [Node]
    # @return [Hash]
    def ensure(node)
      @default_ipam_pool = self.ensure_default_pool(node.grid_subnet, node.grid_iprange)

      {
        pool_id: @default_ipam_pool['PoolID'],
        pool_subnet: @default_ipam_pool['Pool'],
      }
    end

    # @raise [Docker::Error]
    def ensure_weavewait
      unless container = inspect_container(WEAVEWAIT_NAME)
        container = Docker::Container.create(
          'name' => WEAVEWAIT_NAME,
          'Image' => WEAVEEXEC_IMAGE,
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

    # TODO: retry on temporary IPAM errors?
    #
    # @param subnet [String]
    # @param iprange [String]
    def ensure_default_pool(subnet, iprange)
      info "Ensuring default network IPAM pool=#{DEFAULT_NETWORK} with subnet=#{subnet} iprange=#{iprange}"

      ipam_client.reserve_pool(DEFAULT_NETWORK, subnet, iprange)
    end

    # Valid after ensure
    #
    # @return [String]
    def ipam_default_pool
      @default_ipam_pool['PoolID']
    end

    # IP of local weave DNS resolver
    #
    # @return [String]
    def weave_dns_ip
      # always listens on the docker0 IP
      @weave_dns_ip ||= interface_ip('docker0') # XXX: fails on errors?
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
      overlay_network = self.ipam_default_pool
      overlay_cidr = ipam_client.reserve_address(overlay_network)['Address']

      info "Reserve address for container=#{name} in pool=#{overlay_network}: #{overlay_cidr}"

      return overlay_network, overlay_cidr
    end

    # Modify container create options to use weavewait + reserve overlay network address for later attach.
    #
    # Called from Kontena::ServicePods::Creator.
    #
    # @param opts [Hash] container create options
    # @return [Hash]
    def modify_container_opts(opts)
      container_image = inspect_container_image(opts)
      entrypoint, cmd = build_container_entrypoint(opts, container_image)
      overlay_network, overlay_cidr = reserve_container_address(opts)
      dns_ip = self.weave_dns_ip

      host_config = opts['HostConfig'] ||= {}
      host_config['VolumesFrom'] ||= []
      host_config['VolumesFrom'] << "#{WEAVEWAIT_NAME}:ro"
      host_config['Dns'] = [dns_ip] if dns_ip unless host_config['NetworkMode'].to_s == 'host'

      labels = opts['Labels'] ||= {}
      labels['io.kontena.container.overlay_network'] = overlay_network
      labels['io.kontena.container.overlay_cidr'] = overlay_cidr

      opts
    end
  end
end
