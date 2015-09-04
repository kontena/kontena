module Kontena::Cli::Nodes::Aws
  class RestartCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "NAME", "Node name"
    option "--access-key", "ACCESS_KEY", "AWS access key ID", required: true
    option "--secret-key", "SECRET_KEY", "AWS secret key", required: true
    option "--region", "REGION", "EC2 Region", required: true

    def execute
      require_api_url
      require_current_grid

      require 'kontena/machine/aws'

      client = Fog::Compute.new(:provider => 'AWS', :aws_access_key_id => access_key, :aws_secret_access_key => secret_key, :region => region)
      instance = client.servers.all({'tag:kontena_name' => name}).first
      if instance
        instance.reboot
        ShellSpinner "Restarting AWS instance #{name.colorize(:cyan)} " do
          instance.wait_for { ready? }
        end
      else
        abort "Cannot find droplet #{name.colorize(:cyan)} in DigitalOcean"
      end
    end
  end
end
