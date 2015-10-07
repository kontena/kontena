module Kontena::Cli::Containers
  class InspectCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "CONTAINER_ID", "Container id"

    def execute
      require_api_url
      token = require_token

      service_name = container_id.match(/(.+)-(\d+)/)[1]
      result = client(token).get("containers/#{current_grid}/#{service_name}/#{container_id}/inspect")
      puts JSON.pretty_generate(result)
    end
  end
end
