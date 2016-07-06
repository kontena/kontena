require 'docker'
require_relative '../helpers/iface_helper'

module Kontena
  module Rpc

    ##
    # Docker::Container RPC wrapper
    # for more information about opts,
    # see https://github.com/swipely/docker-api#containers
    #
    class DockerContainerApi
      include Kontena::Helpers::IfaceHelper
      include Kontena::Logging

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
      # @return [Hash]
      def start(id)
        container = Docker::Container.get(id)
        container.start
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

      ##
      # @param [String] id
      #
      def inspect(id)
        container = Docker::Container.get(id)
        container.json
      end

    end
  end
end
