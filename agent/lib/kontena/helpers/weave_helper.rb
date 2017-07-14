require 'docker'
require_relative 'iface_helper'
require_relative 'wait_helper'


module Kontena
  module Helpers
    module WeaveHelper
      include WaitHelper

      WEAVE_VERSION = ENV['WEAVE_VERSION'] || '1.9.3'
      WEAVE_IMAGE = ENV['WEAVE_IMAGE'] || 'weaveworks/weave'
      WEAVEEXEC_IMAGE = ENV['WEAVEEXEC_IMAGE'] || 'weaveworks/weaveexec'

      # @param [Docker::Container] container
      # @return [Boolean]
      def adapter_container?(container)
        adapter_image?(container.config['Image'])
      rescue Docker::Error::NotFoundError
        false
      end

      # @param [String] image
      # @return [Boolean]
      def adapter_image?(image)
        image.split(':').first == WEAVEEXEC_IMAGE
      end

      # @param [String] image
      # @return [Boolean]
      def router_image?(image)
        image.split(':').first == WEAVE_IMAGE
      end

      def network_adapter
        Celluloid::Actor[:network_adapter]
      end

      def weaveexec_pool
        Celluloid::Actor[:weave_exec_pool]
      end

      def weaveexec!(*cmd, &block)
        weaveexec_pool.weaveexec!(*cmd, &block)
      end

      # XXX
      def wait_weave_running?
        wait_until!("weave running", timeout: 300) {
          network_adapter.running?
        }
      end

      # XXX
      def wait_network_ready?
        wait_until!("network ready", timeout: 300) {
          network_adapter.network_ready?
        }
      end
    end
  end
end
