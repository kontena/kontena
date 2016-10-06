module Kontena::Cli::Containers
  class InspectCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "CONTAINER_ID", "Container id"

    requires_current_master_token

    def execute
      match = container_id.match(/(.+)-(\d+)/)
      if match
        service_name = match[1]
        result = client.get("containers/#{current_grid}/#{service_name}/#{container_id}/inspect")
        puts JSON.pretty_generate(result)
      else
        exit_with_error("Cannot resolve container service")
      end
    end
  end
end
