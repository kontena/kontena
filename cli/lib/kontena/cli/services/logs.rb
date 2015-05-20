require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Services
  class Logs
    include Kontena::Cli::Common

    ##
    # @param [String] service_id
    def show(service_id, options)
      require_api_url
      token = require_token
      last_id = nil
      loop do
        query_params = last_id.nil? ? '' : "from=#{last_id}"
        result = client(token).get("services/#{service_id}/container_logs?#{query_params}")
        result['logs'].each do |log|
          puts log['data']
          last_id = log['id']
        end
        break unless options.follow
        sleep(2)
      end
    end
  end
end