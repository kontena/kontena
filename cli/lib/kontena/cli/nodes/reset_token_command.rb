module Kontena::Cli::Nodes
  class ResetTokenCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    requires_current_master
    requires_current_master_token
    requires_current_grid

    parameter "NODE", "Node name"

    option ["--token"], "TOKEN", "Use given node token instead of generating a random token"
    option ["--clear-token"], :flag, "Clear node token, reverting to grid token"
    option "--[no-]reset-connection", :flag, "Reset agent websocket connection", default: true
    option "--force", :flag, "Force token update"

    def execute
      confirm("Resetting the node token will disconnect the agent (unless using --no-reset-connection), and require you to reconfigure the kontena-agent using the new `kontena node env` values before it will be able to reconnect. Are you sure?")

      spinner "Resetting node #{pastel.cyan(self.node)} websocket connection token" do
        if self.clear_token?
          client.delete("nodes/#{current_grid}/#{self.node}/token",
            reset_connection: self.reset_connection?,
          )
        else
          client.put("nodes/#{current_grid}/#{self.node}/token",
            token: self.token,
            reset_connection: self.reset_connection?,
          )
        end
      end
    end
  end
end
