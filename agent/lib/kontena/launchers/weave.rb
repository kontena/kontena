module Kontena::Launchers
  # Manage the weaver router container and host weave bridge
  class Weave
    include Celluloid
    include Kontena::Logging
    include Kontena::Actors::Observer
    include Kontena::Helpers::LauncherHelper
    include Kontena::Helpers::WeaveExecHelper

    # XXX: Only run one task at a time
    #exclusive

    def container_name
      'weave'
    end

    def weave_password
      ENV['KONTENA_TOKEN']
    end

    # @param node_info [Kontena::Actor::Observable<Kontena::Models::NodeInfo>]
    def initialize(node_info_observable, start: true)
      @node_info_observable = node_info_observable

      async.start if start
    end

    def start
      info "start..."

      observe node_info: @node_info_observable do
        up(@node_info)
      end
    end

    # Ensure from node_info configuration
    #
    # @param node_info [Kontena::Models::NodeInfo]
    def up(node_info)
      info "up..."

      # TODO: use image = ... ID?
      ensure_image(self.weave_image)
      ensure_running(
        image: self.weave_image,
        options: {
          password: self.weave_password,
          trusted_subnets: node_info.grid_trusted_subnets
        },
      )
      ensure_peers(
        peers: node_info.peer_ips,
      )
      ensure_exposed(
        cidr: node_info.overlay_cidr,
      )

    rescue => error
      error "Failed to launch weave, restarting in 5s: #{error}"

      # XXX: this delays the traceback..
      sleep 5
      raise
    else
      Celluloid::Notifications.publish('weave:up', true)
    end

    ## The weaver container and weave bridge
    def weave_option(cmd, option)
      (i = cmd.find_index(option)) ? cmd[i + 1] : nil
    end

    def weave_trusted_subnets(container)
      if option = weave_option(container.cmd, '--trusted-subnets')
        option.split(',')
      else
        nil
      end
    end

    # @return [Array{Docker::Container, Boolean, Hash}] container, running, config
    def inspect_running
      return nil, false, nil unless container = self.get_container

      return container, container.running?, {
        image: container.config['Image'],
        options: {
          password: container.env_hash['WEAVE_PASSWORD'],
          trusted_subnets: self.weave_trusted_subnets(container),
        },
      }
    end

    def ensure_running(image:, options: )
      container, running, running_config = inspect_running

      if container && running && running_config == {image: image, options: options}
        info "Attaching existing weave..."
        attach!
      else
        if running
          info "Restarting weave..."
          kill! container
        else
          info "Launching weave..."
        end

        launch! **options
      end
    rescue WeaveExecError => error
      warn "Reset weave on error: #{error}"

      reset!

      raise
    end

    ## Weaver is connected to peers
    def ensure_peers(peers: )
      if peers.empty?
        info "Skip connect without peers"
        return
      end

      info "Connect peers=#{peers}"

      # idempotent
      connect! peers
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
    def ensure_exposed(cidr: )
      exposed = inspect_exposed

      # configure new address
      # these will be added alongside any existing addresses
      # XXX: idempotent?
      info "Expose host node at cidr=#{cidr}"
      weaveexec!('expose', cidr)

      # cleanup any old addresses
      if exposed
        exposed.each do |exposed_cidr|
          if exposed_cidr != cidr
            warn "Migrating host node from cidr=#{exposed_cidr}"
            weaveexec!('hide', exposed_cidr)
          end
        end
      end
    end

    ## Operations

    # Start the weaver container and weave bridge
    #
    # Fails if the weaver container is already running
    #
    # @param password [String]
    # @param trusted_subnets [Array<String>]
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
    # Requires that the weaver container is already runnin!g
    def attach!
      weaveexec!('attach-router')
    end

    # Connect the weave router to the given peers
    #
    # Fails if the weaver container is not running.
    # Idempotent?
    #
    # @param [Array<String>] peers
    def connect!(peers)
      weaveexec!('connect', '--replace', *peers)
    end

    # Stop and remove the weaver container.
    #
    # This does not remove the weave bridge.
    #
    # @param container [Docker::Container]
    def kill!(container)
      container.delete(force: true)
    end

    # Stop and remove the weaver container and weave bridge
    def reset!
      weaveexec!('reset')
    rescue Weave::Exec::Error => error
      error "Failed to reset weave: #{error}"
    end
  end
end
