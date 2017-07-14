module Kontena::Launchers
  # Manage the weave router container and host weave bridge, routing
  class Weave
    include Celluloid
    include Kontena::Logging
    include Kontena::Observer
    include Kontena::Observable
    include Kontena::NetworkAdapters::WeaveExec

    CONTAINER_NAME = 'weave'

    def weave_password
      ENV['KONTENA_TOKEN']
    end

    # @param node_info [Kontena::Actor::Observable<Kontena::Models::NodeInfo>]
    def initialize(start: true)
      async.start if start
    end

    def start
      info "start..."

      observe(Actor[:node_info_worker]) do |node|
        launch(node)
      end
    end

    # @param node [Node]
    def launch(node)
      state = up(node)

      update_observable(state)

    rescue => exc
      error exc

      reset_observable
    end

    # Ensure weave router is running, using node configuration
    #
    # @param node [Node]
    # @return [Hash] observable state
    def up(node)
      info "up..."

      state = {}

      state.merge! self.ensure_image(self.weave_image)
      state.merge! self.ensure(self.weave_image,
        password: self.weave_password,
        trusted_subnets: node.grid_trusted_subnets
      )
      state.merge! self.ensure_peers(node.peer_ips)
      state.merge! self.ensure_exposed(node.overlay_cidr)

      return state
    end

    # @param [String] image:version
    # @return [Hash] { image }
    def ensure_image(name)
      unless image = Docker::Image.exist?(name)
        debug "ensure_image: create #{name}"

        image = Docker::Image.create('fromImage' => name)
      end

      return {
        image: name,
      }
    end

    ## The weaver container and weave bridge

    # @return [Docker::Container] nil if not found
    def inspect_container
      Docker::Container.get(CONTAINER_NAME)
    rescue Docker::Error::NotFoundError => error
      nil
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
      return nil unless container = self.inspect_container

      return {
        image: container.config['Image'],
        container: container,
        running: container.running?,
        options: {
          password: self.inspect_weave_password(container),
          trusted_subnets: self.inspect_trusted_subnets(container),
        },
      }
    end

    # @return [Hash{image: String, options: Hash{password, trusted_subnets}}]
    def ensure(image, options)
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

    rescue WeaveExecError => error
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

    # @return [Array<String>, nil] exposed CIDRs
    def inspect_exposed
      weaveexec_ps('weave:expose') do |name, mac, *cidrs|
        return cidrs
      end
      return nil
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
    rescue WeaveExecError => error
      warn "Failed to reset weave: #{error}"
    end
  end
end
