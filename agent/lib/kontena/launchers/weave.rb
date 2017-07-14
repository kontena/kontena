require_relative '../helpers/weave_helper'
require_relative '../helpers/launcher_helper'

module Kontena::Launchers
  # Manage the weave router container and host weave bridge, routing
  class Weave
    include Celluloid
    include Kontena::Logging
    include Kontena::Observer
    include Kontena::Observable
    include Kontena::Helpers::WeaveHelper
    include Kontena::Helpers::LauncherHelper

    IMAGE = "#{WEAVE_IMAGE}:#{WEAVE_VERSION}"

    CONTAINER_NAME = 'weave'

    # @param node_info [Kontena::Actor::Observable<Kontena::Models::NodeInfo>]
    def initialize(start: true)
      async.start if start
    end

    def start
      info "start..."

      self.ensure_image(IMAGE)
      self.ensure_image(Kontena::NetworkAdapters::WeaveExec::IMAGE)

      observe(Actor[:node_info_worker]) do |node|
        update(node)
      end
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

    # Ensure weave router is running, using node configuration
    #
    # @param node [Node]
    # @return [Hash] observable state
    def ensure(node)
      info "ensure..."

      state = {}
      state.merge! self.ensure_container(IMAGE,
        password: node.weave_secret,
        trusted_subnets: node.grid_trusted_subnets
      )
      state.merge! self.ensure_peers(node.peer_ips)
      state.merge! self.ensure_exposed(node.overlay_cidr)

      state.merge! self.query_status

      return state
    end

    # Extract given --option from running container command
    #
    # @param container [Docker::Container]
    # @return [String, nil]
    def inspect_container_option(container, option)
      (i = container.cmd.find_index(option)) ? container.cmd[i + 1] : nil
    end

    # Inspect --password of running container
    #
    # @return [String]
    def inspect_weave_password(container)
      container.env_hash['WEAVE_PASSWORD']
    end

    # Inspect --trusted-subnets of running container
    #
    # @param container [Docker::Container]
    # @return [Array<String>, nil]
    def inspect_trusted_subnets(container)
      if option = inspect_container_option(container, '--trusted-subnets')
        option.split(',')
      else
        nil
      end
    end

    # @return [Hash] {image, running, options} or nil if not exists
    def inspect
      return nil unless container = inspect_container(CONTAINER_NAME)

      return {
        image: container.config['Image'],
        container: container, # XXX: just container.id?
        running: container.running?,
        options: {
          password: self.inspect_weave_password(container),
          trusted_subnets: self.inspect_trusted_subnets(container),
        },
      }
    end

    # @return [Hash{image: String, options: Hash{password, trusted_subnets}}]
    def ensure_container(image, options)
      state = self.inspect

      if state && state[:image] == image && state[:running] && state[:options] == options
        info "Attaching existing weave..."
        weaveexec_attach!
      elsif state
        info "Restarting weave..."
        destroy! state[:container]
        launch! **options
      else
        info "Launching weave..."
        launch! **options
      end

      return {
        image: image,
        options: options,
      }

    rescue Kontena::NetworkAdapters::WeaveExec::WeaveExecError => error
      warn "Reset weave on error: #{error}"

      weaveexec_reset!

      raise
    end

    # @param peers [Array<String>]
    # @raise [WeaveExecError]
    # @raise [Docker::Error]
    # @return [Hash{ peers: [ String ] }]
    def ensure_peers(peers)
      if peers.empty?
        info "Skip connect without peers"
        return
      end

      info "Connect peers: #{peers.join ' '}"

      # idempotent
      weaveexec_connect! peers

      return {
        peers: peers,
      }
    end

    ## The weave bridge's host overlay address and routing

    # Current host addresses exposed on the weave bridge.
    #
    # @raise [WeaveExecError]
    # @return [Array<String>, nil] exposed CIDRs
    def inspect_exposed
      exposed = nil
      weaveexec_pool.ps!('weave:expose') do |name, mac, *cidrs|
        # XXX: can't return because this is a celluloid block call
        exposed = cidrs
      end
      return exposed
    end

    # Ensure that the host weave bridge is exposed using the given CIDR address,
    # and only the given CIDR address
    #
    # @param [String] cidr '10.81.0.X/16'
    # @raise [WeaveExecError]
    # @raise [Docker::Error]
    # @return [Hash{exposed: [String]}]
    def ensure_exposed(cidr)
      exposed = inspect_exposed

      # configure new address
      # these will be added alongside any existing addresses
      # XXX: idempotent?
      info "Expose host node: #{cidr}"
      weaveexec!('expose', "ip:#{cidr}")

      # cleanup any old addresses
      if exposed
        exposed.each do |exposed_cidr|
          if exposed_cidr != cidr
            warn "Migrating host node from cidr=#{exposed_cidr}"
            weaveexec!('hide', exposed_cidr)
          end
        end
      end

      return {
        exposed: [ cidr ],
      }
    end

    # Query weave status
    #
    # @raise [Excon::Error]
    # @return [Hash{status: String}]
    def query_status
      {
        status: weave_client.status,
      }
    end

    ## Operations

    # Stop and remove the weaver container.
    #
    # This does not remove the weave bridge.
    #
    # @param container [Docker::Container]
    # @raise [Docker::Error]
    def destroy!(container)
      container.delete(force: true)
    end

    # Start the weaver container and weave bridge
    #
    # Fails if the weaver container is already running
    #
    # @param password [String]
    # @param trusted_subnets [Array<String>]
    # @raise [WeaveExecError]
    # @raise [Docker::Error]
    def launch!(password:, trusted_subnets: [])
      weaveexec!('launch-router',
        '--ipalloc-range', '',
        '--dns-domain', 'kontena.local',
        '--password', password,
        '--trusted-subnets', trusted_subnets.join(','),
      )
    end

    # Start the weave bridge
    #
    # Requires that the weaver container is already running!
    #
    # @raise [WeaveExecError]
    # @raise [Docker::Error]
    def weaveexec_attach!
      weaveexec!('attach-router')
    end

    # Connect the weave router to the given peers
    #
    # Fails if the weaver container is not running.
    # Idempotent?
    #
    # @param [Array<String>] peers
    # @raise [WeaveExecError]
    # @raise [Docker::Error]
    def weaveexec_connect!(peers)
      weaveexec!('connect', '--replace', *peers)
    end

    # Stop and remove the weaver container and weave bridge.
    #
    # Rescues any weaveexec error as a warning.
    #
    # @raise [Docker::Error]
    def weaveexec_reset!
      weaveexec!('reset')
    rescue Kontena::NetworkAdapters::WeaveExec::WeaveExecError => error
      warn "Failed to reset weave: #{error}"
    end
  end
end
