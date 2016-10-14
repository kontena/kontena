module Kontena::Cli::ExternalRegistries
  class AddCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter '[URL]', 'Docker Registry url', default: 'https://index.docker.io/v2/'

    option ['-u', '--username'], 'USERNAME', 'Username', required: true
    option ['-e', '--email'], 'EMAIL', 'Email', required: true
    option ['-p', '--password'], 'PASSWORD', 'Password', required: true

    requires_current_master_token

    def execute
      data = { username: username, password: password, email: email, url: url }
      spinner "Adding #{url.colorize(:cyan)} to external registries " do
        client.post("grids/#{current_grid}/external_registries", data)
      end
    end
  end
end
