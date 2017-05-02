module Kontena::Cli::Containers
  class InspectCommand < Kontena::Command
    include Kontena::Cli::GridOptions

    parameter "CONTAINER_ID", "Container id"

    def execute
      require_api_url
      token = require_token

      result = client(token).get("containers/#{current_grid}/#{container_id}/inspect")
      puts JSON.pretty_generate(result)
    end
  end
end
