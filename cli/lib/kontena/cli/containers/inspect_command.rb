module Kontena::Cli::Containers
  class InspectCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "CONTAINER_ID", "Container id"

    def execute
      require_api_url
      token = require_token

      match = container_id.match(/(.+)-(\d+)/)
      if match
        service_name = match[1]
        result = client(token).get("containers/#{current_grid}/#{service_name}/#{container_id}/inspect")
        puts JSON.pretty_generate(result)
      else
        abort("Cannot resolve container service")
      end
    end
  end
end
