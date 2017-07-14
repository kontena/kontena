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

      # @return [String]
      def weave_version
        WEAVE_VERSION
      end

      # @return [String]
      def weave_image
        "#{WEAVE_IMAGE}:#{WEAVE_VERSION}"
      end

      # @return [String]
      def weaveexec_image
        "#{WEAVEEXEC_IMAGE}:#{WEAVE_VERSION}"
      end

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
        image.to_s.include?(WEAVEEXEC_IMAGE)
      rescue
        false
      end

      # @param [String] image
      # @return [Boolean]
      def router_image?(image)
        image.to_s == "#{WEAVE_IMAGE}:#{WEAVE_VERSION}"
      rescue
        false
      end

      def network_adapter
        Celluloid::Actor[:network_adapter]
      end

      def wait_weave_running?
        wait_until!("weave running", timeout: 300) {
          network_adapter.running?
        }
      end

      def wait_network_ready?
        wait_until!("network ready", timeout: 300) {
          network_adapter.network_ready?
        }
      end
    end
  end
end
