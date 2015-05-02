require 'docker'

module Kontena
  module Rpc

    ##
    # Docker::Image RPC wrapper
    # for more information about opts,
    # see https://github.com/swipely/docker-api#images
    #
    class DockerImageApi

      ##
      # @param [Hash] opts
      # @param [Hash] creds
      # @return [Hash]
      def create(opts, creds = nil)
        image = Docker::Image.create(opts, creds)
        image.json
      end

      ##
      # @param [String] name
      # @return [Hash]
      def show(name)
        image = Docker::Image.get(name)
        image.json
      rescue Docker::Error::NotFoundError => exc
        raise RpcServer::Error.new(404, 'Not found')
      end
    end
  end
end
