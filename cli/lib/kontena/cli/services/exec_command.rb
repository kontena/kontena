module Kontena::Cli::Services
  class ExecCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "Service name"
    parameter "CMD ...", "Command"
    option ["-i", "--instance"], "INSTANCE", "Execute command in given instance", default: "1"

    def execute
      require_api_url
      token = require_token

      payload = {
        cmd: ['sh', '-c', cmd_list.join(' ')],
        instance: instance
      }
      service_name = container_id.match(/(.+)-(\d+)/)[1]
      result = client(token).post("services/#{current_grid}/#{name}/exec", payload)
      puts result[0].join(" ") unless result[0].size == 0
      STDERR.puts result[1].join(" ") unless result[1].size == 0
      exit result[2]
    end
  end
end
