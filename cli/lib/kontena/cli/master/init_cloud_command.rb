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

    def master_config
      @master_config ||= client.get('config')
    end

    def current_master_cloud_config
      return @cloud_config if @cloud_config
      master_client_id = master_config['oauth2.client_id']
      @cloud_config = cloud_client.get('user/masters')['data'].find { |cm| cm['attributes']['client-id'] == master_client_id }
    end

    def current_master_cloud_name
      @cloud_name ||= current_master_cloud_config.nil? ? nil : current_master_cloud_config['attributes']['name']
    end

    def already_cloud_enabled?
      !current_master_cloud_config.nil?
    end

    def execute
      exit_with_error "Current master is already registered to use Kontena Cloud as #{pastel.cyan(current_master_cloud_name)}" if already_cloud_enabled?
      args = ["--current"]
      args << "--force" if self.force?
      args += ["--cloud-master-id", self.cloud_master_id.shellescape] if self.cloud_master_id
      args += ["--provider", self.provider.shellescape] if self.provider
      args += ["--version", self.version.shellescape] if self.version
      Kontena.run!(['cloud', 'master', 'add'] + args)
    end
  end
end
