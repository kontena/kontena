module Kontena
  module Helpers
    module NodeHelper

      # @return [String]
      def master_url
        ENV['KONTENA_URI'].sub('ws', 'http')
      end

      # @return [Hash]
      def docker_info
        @docker_info ||= Docker.info
      end

      # @return [String]
      def node_id
        docker_info['ID']
      end
    end
  end
end
