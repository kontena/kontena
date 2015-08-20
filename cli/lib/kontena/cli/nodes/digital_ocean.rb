require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Nodes
  class DigitalOcean
    include Kontena::Cli::Common

    def provision(options)
      require_api_url
      require_current_grid

      require 'kontena/machine/digital_ocean'
      grid = client(require_token).get("grids/#{current_grid}")
      provisioner = Kontena::Machine::DigitalOcean::NodeProvisioner.new(client(require_token), options.token)
      provisioner.run!(
        master_uri: api_url,
        grid_token: grid['token'],
        grid: current_grid,
        ssh_key: options.ssh_key,
        name: options.name,
        size: options.size || '1gb',
        region: options.region || 'ams3',
      )
    end

    def destroy(name, token)
      require_api_url
      require_current_grid

      require 'kontena/machine/digital_ocean'
      grid = client(require_token).get("grids/#{current_grid}")
      destroyer = Kontena::Machine::DigitalOcean::NodeDestroyer.new(client(require_token), token)
      destroyer.run!(grid, name)
    end
  end
end
