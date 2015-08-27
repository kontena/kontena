module Kontena::Cli::Nodes::Vagrant
  class CreateCommand < Clamp::Command
    include Kontena::Cli::Common

    option "--name", "NAME", "Node name"
    option "--memory", "MEMORY", "How much memory node has (default: 1024)"
    option "--version", "VERSION", "Define installed Kontena version (default: #{Kontena::Cli::VERSION})"

    def execute
      require_api_url
      require_current_grid

      require 'kontena/machine/vagrant'
      grid = client(require_token).get("grids/#{current_grid}")
      provisioner = Kontena::Machine::Vagrant::NodeProvisioner.new(client(require_token))
      provisioner.run!(
        master_uri: api_url,
        grid_token: grid['token'],
        grid: current_grid,
        name: name,
        memory: memory || '1024',
        version: version || Kontena::Cli::VERSION
      )
    end
  end
end
