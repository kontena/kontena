module Kontena::Cli::Master
  class InitCloudCommand < Kontena::Command

    include Kontena::Cli::Common

    banner "Configures the current Kontena Master to use Kontena Cloud services and authentication"

    option '--force',           :flag,  "Don't ask questions"
    option '--cloud-master-id', '[ID]', "Use existing cloud master ID"

    requires_current_master
    requires_current_account_token

    def execute
      args = ["--current"]
      args << "--force" if self.force?
      args << "--cloud-master-id #{self.cloud_master_id}" if self.cloud_master_id
      Kontena.run("cloud master add #{args.map(&:shellescape).join(' ')}")
    end
  end
end
