require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Services
  class Logs
    include Kontena::Cli::Common

    ##
    # @param [String] service_id
    def show(service_id)
      require_api_url
      token = require_token

      result = client(token).get("services/#{service_id}/container_logs")
      result['logs'].each do |log|
        puts log['data']
      end
    end
  end
end