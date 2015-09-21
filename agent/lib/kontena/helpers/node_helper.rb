module Kontena
  module Helpers
    module NodeHelper

      # @return [Hash, NilClass]
      def node_info
        response = Excon.get("#{master_url}/v1/nodes/#{node_id}", headers: {
          'Content-Type' => 'application/json',
          'Kontena-Grid-Token' => ENV['KONTENA_TOKEN']
        })
        if response.status == 200
          return JSON.load(response.body)
        end
        nil
      end

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
