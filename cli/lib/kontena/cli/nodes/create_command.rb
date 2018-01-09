module Kontena::Cli::Nodes
  class CreateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    requires_current_master
    requires_current_master_token
    requires_current_grid

    parameter "NAME", "Node name"
    option ["--token"], "TOKEN", "Node token"
    option ["-l", "--label"], "LABEL", "Node label", multivalued: true

    def execute
      data = { name: name }

      data[:token] = token if token
      data[:labels] = label_list

      spinner "Creating #{pastel.cyan(name)} node " do
        client.post("grids/#{current_grid}/nodes", data)
      end
    end
  end
end
