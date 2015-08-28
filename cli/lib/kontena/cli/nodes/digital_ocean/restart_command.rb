module Kontena::Cli::Nodes::DigitalOcean
  class RestartCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "NAME", "Node name"
    option "--token", "TOKEN", "DigitalOcean API token", required: true

    def execute
      require_api_url
      require_current_grid

      require 'kontena/machine/digital_ocean'

      client = DropletKit::Client.new(access_token: token)
      droplet = client.droplets.all.find{|d| d.name == name}
      if droplet
        ShellSpinner "Restarting DigitalOcean droplet #{name.colorize(:cyan)} " do
          client.droplet_actions.reboot(droplet_id: droplet.id)
          sleep 5 until client.droplets.find(id: droplet.id).status == 'active'
        end
      else
        abort "Cannot find droplet #{name.colorize(:cyan)} in DigitalOcean"
      end
    end
  end
end
