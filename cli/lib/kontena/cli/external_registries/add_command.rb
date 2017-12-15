module Kontena::Cli::ExternalRegistries
  class AddCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter '[URL]', 'Docker Registry url', default: 'https://index.docker.io/v2/'

    option ['-u', '--username'], 'USERNAME', 'Username', required: true
    option ['-p', '--password'], 'PASSWORD', 'Password', required: true
    option ['-e', '--email'], 'EMAIL', 'Email', required: false

    def execute
      require_api_url
      require_current_grid
      token = require_token

      self.url = "https://#{self.url}" unless self.url.start_with?('http')

      data = { username: username, password: password, email: email, url: url }
      spinner "Adding #{url.colorize(:cyan)} to external registries " do
        client(token).post("grids/#{current_grid}/external_registries", data)
      end
    end
  end
end
