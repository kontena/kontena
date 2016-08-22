require_relative '../grid_options'
require_relative './containers_helper'

module Kontena::Cli::Containers
  class ExecCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ContainersHelper

    parameter "CONTAINER_ID", "Container id"
    parameter "CMD ...", "Command"

    def execute
      require_api_url
      token = require_token

      cmd = build_command(cmd_list)
      payload = {cmd: ["sh", "-c", cmd]}

      service_name = container_id.match(/(.+)-(\d+)/)[1] rescue nil
      result = client(token).post("containers/#{current_grid}/#{service_name}/#{container_id}/exec", payload)

      puts result[0].join(" ") unless result[0].size == 0
      STDERR.puts result[1].join(" ") unless result[1].size == 0
      exit result[2]
    end
  end
end
