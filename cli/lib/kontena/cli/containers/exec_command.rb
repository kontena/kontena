require_relative '../grid_options'
require_relative 'container_id_param'

module Kontena::Cli::Containers
  class ExecCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    include Kontena::Cli::Containers::ContainerIdParam

    parameter "CMD ...", "Command"

    requires_current_master
    requires_current_master_token

    def exec(payload, container_id)
      client.post("containers/#{current_grid}/#{container_id}/exec", payload)
    rescue Kontena::Errors::StandardError => ex
      if ex.message =~ /Not [Ff]ound/
        if new_target = resolve(container_id)
          return exec(payload, new_target)
        end
      end
      raise ex, ex.message
    end

    def execute
      payload = {cmd: ["sh", "-c", Shellwords.join(cmd_list)]}
      result = exec(payload, container_id)
      puts result[0].join(" ") unless result[0].size == 0
      STDERR.puts result[1].join(" ") unless result[1].size == 0
      exit result[2]
    end
  end
end
