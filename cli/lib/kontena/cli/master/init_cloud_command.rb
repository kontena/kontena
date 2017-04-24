module Kontena::Cli::Master
  class InitCloudCommand < Kontena::Command

    include Kontena::Cli::Common

    banner "Configures the current Kontena Master to use Kontena Cloud services and authentication"

    option '--force',           :flag,       "Don't ask questions"
    option '--cloud-master-id', '[ID]',      "Use existing cloud master ID"
    option '--provider',        '[NAME]',    "Set master provider name"
    option '--version',         '[VERSION]', "Set master version"

    requires_current_master
    requires_current_master_token
    requires_current_account_token

    def execute
      args = ["--current"]
      args << "--force" if self.force?
      args += ["--cloud-master-id", self.cloud_master_id.shellescape] if self.cloud_master_id
      args += ["--provider", self.provider.shellescape] if self.provider
      args += ["--version", self.version.shellescape] if self.version
      Kontena.run(['cloud', 'master', 'add'] + args)
    end
  end
end
