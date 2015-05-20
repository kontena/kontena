require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Containers
  class Containers
    include Kontena::Cli::Common

    def exec(container_id, cmd)
      require_api_url
      token = require_token

      payload = {cmd: ['sh', '-c', cmd]}
      result = client(token).post("containers/#{container_id}/exec", payload)
      puts result
    end
  end
end
