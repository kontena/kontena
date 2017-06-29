module Kontena::Cli::Nodes
  class UpdateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    requires_current_master
    requires_current_master_token
    requires_current_grid

    parameter "NAME", "Node name"

    option ["--token"], "TOKEN", "Node token"
    option "--generate-token", :flag, "Generate new node token"

    option ["-l", "--label"], "LABEL", "Node label", multivalued: true
    option "--clear-labels", :flag, "Clear node labels"

    def update_token
      data = {}

      data[:token] = self.token if self.token

      spinner "Updating node #{name.colorize(:cyan)} token" do
        client.put("nodes/#{current_grid}/#{name}/token", data)
      end
    end

    def execute
      self.update_token if self.token or self.generate_token?

      data = {}

      data[:labels] = self.label_list unless self.label_list.empty?
      data[:labels] = [] if self.clear_labels?

      if data.empty?
        warn "Nothing to update?"
      else
        spinner "Updating #{name.colorize(:cyan)} node " do
          client.put("nodes/#{current_grid}/#{name}", data)
        end
      end
    end
  end
end
