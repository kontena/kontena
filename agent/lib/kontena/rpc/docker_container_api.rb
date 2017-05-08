require 'docker'
require_relative '../helpers/iface_helper'
require_relative '../actors/container_exec'
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
      rescue Docker::Error::NotFoundError
        raise RpcServer::Error.new(404, 'Not found')
      end

      ##
      # @param [String] id
      # @return [Hash]
      def start(id)
        container = Docker::Container.get(id)
        container.start
        container.json
      rescue Docker::Error::NotFoundError
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
      rescue Docker::Error::NotFoundError
        raise RpcServer::Error.new(404, 'Not found')
      end

      ##
      # @param [String] id
      # @return [Hash]
      def pause(id)
        container = Docker::Container.get(id)
        container.pause
        container.json
      rescue Docker::Error::NotFoundError
        raise RpcServer::Error.new(404, 'Not found')
      end

      ##
      # @param [String] id
      # @return [Hash]
      def unpause(id)
        container = Docker::Container.get(id)
        container.unpause
        container.json
      rescue Docker::Error::NotFoundError
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
      rescue Docker::Error::NotFoundError
        raise RpcServer::Error.new(404, 'Not found')
      end

      ##
      # @param [String] id
      # @return [Array]
      def top(id)
        container = Docker::Container.get(id)
        container.top
      rescue Docker::Error::NotFoundError
        raise RpcServer::Error.new(404, 'Not found')
      end

      ##
      # @param [String] id
      # @param [String] cmd
      # @param [Hash] opts
      # @return [Array<(Array<String>, Array<String>, Integer)>] stdout, stderr, exit_status
      def exec(id, cmd, opts = {})
        container = Docker::Container.get(id)
        container.exec(cmd, opts)
      rescue Docker::Error::NotFoundError
        raise RpcServer::Error.new(404, 'Not found')
      end

      def create_exec(id)
        container = Docker::Container.get(id)
        executor = Kontena::Actors::ContainerExec.new(container)
        actor_id = "container_exec_#{executor.uuid}"
        Celluloid::Actor[actor_id] = executor
        { id: executor.uuid }
      rescue Docker::Error::NotFoundError
        raise RpcServer::Error.new(404, 'Container not found')
      end

      def run_exec(id, cmd)
        actor_id = "container_exec_#{id}"
        executor = Celluloid::Actor[actor_id]
        if executor
          executor.async.run(cmd)
        else
          raise RpcServer::Error.new(404, "Exec session (#{id}) not found")
        end

        {}
      end

      def tty_exec(id, cmd)
        actor_id = "container_exec_#{id}"
        executor = Celluloid::Actor[actor_id]
        if executor
          executor.async.interactive(cmd)
        else
          raise RpcServer::Error.new(404, "Exec session (#{id}) not found")
        end

        {}
      end

      def tty_input(id, input)
        actor_id = "container_exec_#{id}"
        executor = Celluloid::Actor[actor_id]
        if executor
          executor.async.input(input)
        end
      end

      def terminate_exec(id)
        actor_id = "container_exec_#{id}"
        executor = Celluloid::Actor[actor_id]
        if executor
          Celluloid::Actor.kill(executor) if executor.alive?
        else
          raise RpcServer::Error.new(404, "Exec session (#{id}) not found")
        end

        {}
      end

      ##
      # @param [String] id
      # @param [Hash] opts
      def delete(id, opts = {})
        container = Docker::Container.get(id)
        container.stop
        container.delete(opts)
      rescue Docker::Error::NotFoundError
        raise RpcServer::Error.new(404, 'Not found')
      end

      ##
      # @param [String] id
      #
      def inspect(id)
        container = Docker::Container.get(id)
        container.json
      rescue Docker::Error::NotFoundError
        raise RpcServer::Error.new(404, 'Not found')
      end
    end
  end
end
