require_relative '../grid_options'

module Kontena::Cli::Containers
  class ExecCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "CONTAINER_ID", "Container id"
    parameter "CMD ...", "Command"

    def execute
      require_api_url
      token = require_token

      payload = {cmd: ["sh", "-c", Shellwords.join(cmd_list)]}
      result = client(token).post("containers/#{current_grid}/#{container_id}/exec", payload)

      puts result[0].join(" ") unless result[0].size == 0
      $stderr.puts result[1].join(" ") unless result[1].size == 0
      exit result[2]
    end
  end
end
