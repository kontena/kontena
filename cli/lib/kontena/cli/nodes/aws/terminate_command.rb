module Kontena::Cli::Nodes::Aws
  class TerminateCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "Node name"
    option "--access-key", "ACCESS_KEY", "AWS access key ID", required: true
    option "--secret-key", "SECRET_KEY", "AWS secret key", required: true
    option "--region", "REGION", "EC2 Region", default: 'eu-west-1'

    def execute
      require_api_url
      require_current_grid

      require 'kontena/machine/aws'
      grid = client(require_token).get("grids/#{current_grid}")
      destroyer = Kontena::Machine::Aws::NodeDestroyer.new(client(require_token), access_key, secret_key, region)
      destroyer.run!(grid, name)
    end
  end
end
