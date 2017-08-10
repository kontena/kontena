module Kontena
  module Helpers
    module WeaveHelper
      WEAVE_VERSION = ENV['WEAVE_VERSION'] || '1.9.3'
      WEAVE_IMAGE = ENV['WEAVE_IMAGE'] || 'weaveworks/weave'
      WEAVEEXEC_IMAGE = ENV['WEAVEEXEC_IMAGE'] || 'weaveworks/weaveexec'

      def weave_executor
        Celluloid::Actor[:weave_executor]
      end

      def weaveexec!(*cmd, &block)
        weave_executor.weaveexec!(*cmd, &block)
      end

      def weave_client
        @weave_client ||= Kontena::NetworkAdapters::WeaveClient.new
      end
    end
  end
end
