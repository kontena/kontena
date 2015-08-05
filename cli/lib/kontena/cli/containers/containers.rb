require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Containers
  class Containers
    include Kontena::Cli::Common

    def exec(container_id, cmd)
      require_api_url
      token = require_token

      payload = {cmd: ['sh', '-c', cmd]}
      service_name = container_id.split("-")[0..-2].join("-")
      result = client(token).post("containers/#{current_grid}/#{service_name}/#{container_id}/exec", payload)
      puts result[0].join(" ") unless result[0].size == 0
      STDERR.puts result[1].join(" ") unless result[1].size == 0
      exit result[2]
    end
  end
end
