module Kontena
  module Helpers
    module NodeHelper

      # @return [String]
      def master_url
        ENV['KONTENA_URI'].sub('ws', 'http')
      end

      # @return [String]
      def node_id
        Docker.info['ID']
      end
    end
  end
end
