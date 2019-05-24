module Kontena::NetworkAdapters
  # Modify container create options to use weavewait + reserve overlay network address for later attach.
  #
  # Observes the Kontena::NetworkAdapters::Weave for the overlay network + IPAM to be ready.
  #
  # Used from Kontena::ServicePods::Creator.
  class ContainerConfigurer
    include Kontena::Logging
    include Kontena::Observer::Helper
    include Kontena::Helpers::WeaveHelper
    include Kontena::Helpers::IfaceHelper

    attr_reader :opts

    # @param opts [Hash] Docker::Container.create! *opts
    def initialize(opts)
      @opts = opts
    end

    def container_name
      @opts['name']
    end

    # @return [Kontena::NetworkAdapters::IpamClient]
    def ipam_client
      @ipam_client ||= IpamClient.new
    end

    # IP of local weave DNS resolver
    #
    # @return [String]
    def weave_dns_ip
      # always listens on the docker0 IP
      @dns_ip ||= interface_ip('docker0') # XXX: fails on errors?
    end

    # @return [Hash{ipam_pool, ipam_subnet}]
    def weave_state
      @weave_state ||= observe(network_observable)
    end

    # @return [String]
    def ipam_pool
      weave_state[:ipam_pool]
    end

    # Lookup Docker image used for container.
    #
    # @return [Hash] Docker::Image.info
    def inspect_container_image
      image = Docker::Image.get(opts['Image'])
      image.info
    end

    # Wrap container entrypoint/command to use the weavewait entrypoint, based on image config.
    #
    # @param opts [Hash] container create options
    # @param image_info [Hash] Docker::Image.info
    # @param entrypoint [Array<String>]
    # @return [String, String] entrypoint, cmd
    def build_container_entrypoint(image_info, entrypoint = '/w/w')
      image_config = image_info['Config']

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

    # @return [String, String] overlay network, cidr
    def reserve_container_address
      overlay_network = self.ipam_pool
      overlay_cidr = ipam_client.reserve_address(overlay_network)['Address']

      info "Reserve address for container=#{self.container_name} in pool=#{overlay_network}: #{overlay_cidr}"

      return overlay_network, overlay_cidr
    end

    # @return [Hash]
    def configure
      image_info = inspect_container_image()
      entrypoint, cmd = build_container_entrypoint(image_info)
      overlay_network, overlay_cidr = reserve_container_address()
      dns_ip = weave_dns_ip

      opts = @opts.dup

      host_config = opts['HostConfig'] ||= {}
      host_config['VolumesFrom'] ||= []
      host_config['VolumesFrom'] << "#{Kontena::NetworkAdapters::Weave::WEAVEWAIT_NAME}:ro"
      host_config['Dns'] = [dns_ip]

      labels = opts['Labels'] ||= {}
      labels['io.kontena.container.overlay_network'] = overlay_network
      labels['io.kontena.container.overlay_cidr'] = overlay_cidr

      opts
    end
  end
end
