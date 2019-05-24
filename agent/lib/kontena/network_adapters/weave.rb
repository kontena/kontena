require_relative '../helpers/iface_helper'
require_relative '../helpers/launcher_helper'
require_relative '../helpers/weave_helper'

module Kontena::NetworkAdapters
  # Configure containers for use with weave.
  # Manages the default IPAM pool, and allocates addresses for contaienrs.
  # The actual container runtime attach happens in the Kontena::Workers::WeaveWorker.
  class Weave
    include Celluloid
    include Kontena::Observable::Helper
    include Kontena::Observer::Helper
    include Kontena::Helpers::LauncherHelper
    include Kontena::Helpers::WeaveHelper
    include Kontena::Logging

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

      observe(Actor[:node_info_worker].observable, Actor[:weave_launcher].observable, Actor[:ipam_plugin_launcher].observable) do |node, weave, ipam|
        async.apply(node)
      end
    end

    # @param node [Node]
    def apply(node)
      exclusive {
        self.observable.update(self.ensure(node))
      }
    end

    # @raise [Docker::Error]
    # @return [Docker::Container]
    def ensure_weavewait
      unless container = inspect_container(WEAVEWAIT_NAME)
        container = Docker::Container.create(
          'name' => WEAVEWAIT_NAME,
          'Image' => Kontena::NetworkAdapters::WeaveExec::IMAGE,
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

    # @param node [Node]
    # @return [Hash]
    def ensure(node)
      @default_ipam_pool ||= self.ensure_default_pool(node.grid_subnet, node.grid_iprange)

      {
        ipam_pool: @default_ipam_pool['PoolID'],
        ipam_subnet: @default_ipam_pool['Pool'],
      }
    end

    # TODO: retry on temporary IPAM errors?
    #
    # @param subnet [String]
    # @param iprange [String]
    def ensure_default_pool(subnet, iprange)
      info "Ensuring default network IPAM pool=#{DEFAULT_NETWORK} with subnet=#{subnet} iprange=#{iprange}"

      ipam_client.reserve_pool(DEFAULT_NETWORK, subnet, iprange)
    end
  end
end
