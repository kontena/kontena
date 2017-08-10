module Kontena::Cli::Volumes::Drivers
  class InstallCommand < Kontena::Command
    include Kontena::Cli::Common


    parameter "NAME", "Driver name"
    parameter "CONFIG ...", "Configuration"

    option "--label", "LABEL", "Install plugin only on nodes matching label"

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def execute

      data = {
        'name' => self.name,
        'config' => self.config_list
      }
      data['label'] = self.label if self.label

      # TODO Needs bigger timeout, installation can be rather slow
      client.post("volumes/#{current_grid}/plugins/install", data)
    end
  end
end