require_relative 'container_id_param'

module Kontena::Cli::Containers
  class InspectCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    include Kontena::Cli::Containers::ContainerIdParam

    requires_current_master
    requires_current_master_token

    def execute
      result = client.get("containers/#{current_grid}/#{container_id}/inspect")
      puts JSON.pretty_generate(result)
    end
  end
end
