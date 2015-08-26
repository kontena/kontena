require 'docker'

module Kontena
  module Rpc

    ##
    # Docker::Container RPC wrapper
    # for more information about opts,
    # see https://github.com/swipely/docker-api#containers
    #
    class DockerContainerApi

      attr_reader :overlay_adapter

      def initialize
        @overlay_adapter = Kontena::WeaveAdapter.new
      end

      ##
      # @param [Hash]
      # @return [Hash]
      def create(opts)
        self.overlay_adapter.modify_create_opts(opts)
        container = Docker::Container.create(opts)
        container.json
      rescue Docker::Error::DockerError => exc
        raise RpcServer::Error.new(400, "Cannot create container #{opts}", exc.backtrace)
      end

      ##
      # @param [String] id
      # @return [Hash]
      def show(id)
        container = Docker::Container.get(id)
        container.json
      rescue Docker::Error::NotFoundError => exc
        raise RpcServer::Error.new(404, 'Not found')
      end

      ##
      # @param [String] id
      # @param [Hash] opts
      # @return [Hash]
      def start(id, opts)
        container = Docker::Container.get(id)
        dns = resolve_dns
        if dns
          opts['Dns'] = [dns]
          opts['DnsSearch'] = ['kontena.local']
        end
        self.overlay_adapter.modify_start_opts(opts)
        container.start(opts)
        container.json
      rescue Docker::Error::NotFoundError => exc
        raise RpcServer::Error.new(404, 'Not found')
      end

      ##
      # @param [String] id
      # @param [Hash] opts
      # @return [Hash]
      def stop(id, opts = {})
        container = Docker::Container.get(id)
        container.stop(opts)
        container.json
      rescue Docker::Error::NotFoundError
        raise RpcServer::Error.new(404, 'Not found')
      end

      ##
      # @param [String] id
      # @return [Hash]
      def restart(id)
        container = Docker::Container.get(id)
        container.restart
        container.json
      rescue Docker::Error::NotFoundError => exc
        raise RpcServer::Error.new(404, 'Not found')
      end

      ##
      # @param [String] id
      # @return [Hash]
      def pause(id)
        container = Docker::Container.get(id)
        container.pause
        container.json
      rescue Docker::Error::NotFoundError => exc
        raise RpcServer::Error.new(404, 'Not found')
      end

      ##
      # @param [String] id
      # @return [Hash]
      def unpause(id)
        container = Docker::Container.get(id)
        container.unpause
        container.json
      rescue Docker::Error::NotFoundError => exc
        raise RpcServer::Error.new(404, 'Not found')
      end

      ##
      # @param [String] id
      # @param [Hash] opts
      # @return [Hash]
      def kill(id, opts = {})
        container = Docker::Container.get(id)
        container.kill(opts)
        container.json
      rescue Docker::Error::NotFoundError => exc
        raise RpcServer::Error.new(404, 'Not found')
      end

      ##
      # @param [String] id
      # @return [Array]
      def top(id)
        container = Docker::Container.get(id)
        container.top
      rescue Docker::Error::NotFoundError => exc
        raise RpcServer::Error.new(404, 'Not found')
      end

      ##
      # @param [String] id
      # @param [String] cmd
      # @param [Hash] opts
      # @return [Array]
      def exec(id, cmd, opts = {})
        container = Docker::Container.get(id)
        container.exec(cmd, opts)
      rescue Docker::Error::NotFoundError => exc
        raise RpcServer::Error.new(404, 'Not found')
      end

      ##
      # @param [String] id
      # @param [Hash] opts
      def delete(id, opts = {})
        container = Docker::Container.get(id)
        container.stop
        container.delete(opts)
      rescue Docker::Error::NotFoundError => exc
        raise RpcServer::Error.new(404, 'Not found')
      end

      private

      def resolve_dns
        `ifconfig docker0 2> /dev/null | awk '/inet addr:/ {print $2}' | sed 's/addr://'`.strip
      end
    end
  end
end
