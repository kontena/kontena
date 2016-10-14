module Kontena::Cli::Cloud::Master
  class AddCommand < Kontena::Command

    include Kontena::Cli::Common

    callback_matcher 'cloud-master', 'create'

    requires_current_account_token

    parameter "[NAME]", "Master name"

    option ['--redirect-uri'], '[URL]',      'Set master redirect URL'
    option ['--url'],          '[URL]',      'Set master URL'
    option ['--provider'],     '[NAME]',     'Set master provider'
    option ['--name'],         '[NAME]',     'Set master name',        hidden: true
    option ['--version'],      '[VERSION]',  'Set master version',     hidden: true
    option ['--owner'],        '[NAME]',     'Set master owner',       hidden: true

    option ['--id'],      :flag, 'Just output the ID'
    option ['--current'], :flag, 'Register and configure current master'
    option ['--return'],  :flag, 'Return the ID', hidden: true
    option ['--force'],   :flag, "Don't ask questions"

    def register(name, url = nil, provider = nil, redirect_uri = nil, version = nil, owner = nil)
      attributes = {}
      attributes['name']         = name 
      attributes['url']          = url if url
      attributes['provider']     = provider if provider
      attributes['redirect-uri'] = redirect_uri if redirect_uri
      attributes['version']      = version if version
      attributes['owner']        = owner if owner

      response = cloud_client.post('user/masters', { data: { attributes: attributes } })
      exit_with_error "Failed (invalid response)" unless response.kind_of?(Hash)
      exit_with_error "Failed (no data)" unless response['data']
      exit_with_error "Failed: #{response['error']}" if response['error']
      response
    end

    def register_current
      require_api_url
      require_token

      unless self.force?
        puts "Proceeding will:"
        puts " * Register the Kontena Master #{current_master.name} to Kontena Cloud"
        puts " * Configure the Kontena Master to use Kontena Cloud as the"
        puts "   authentication provider"
        puts
        puts "After this:"
        puts " * Users will not be able to reauthenticate without authorizing the"
        puts "   Master to access their Kontena Cloud user information"
        puts " * Users that have registered a different email address to Kontena"
        puts "   Cloud than the one they currently have as their username in the"
        puts "   master will not be able to authenticate before an administrator"
        puts "   of the Kontena Master creates an invitation code for them"
        puts "   (kontena master users invite old@email.example.com)"
        exit_with_error "Aborted" unless prompt.yes?("Proceed?")
      end

      response = spinner "Registering current Kontena Master '#{current_master.name}' to Kontena Cloud" do
        register(current_master.name, current_master.url)
      end

      spinner "Loading Kontena Cloud auth provider base configuration to Kontena Master" do
        Kontena.run('master config import --force --preset kontena_auth_provider')
      end

      spinner "Updating OAuth2 client-id and client-secret to Kontena Master" do
        Kontena.run("master config set oauth2.client_id=#{response['data']['attributes']['client-id'].shellescape} oauth2.client_secret=#{response['data']['attributes']['client-secret'].shellescape} server.root_url=#{current_master.url.shellescape} server.name=#{current_master.name.shellescape} cloud.provider_is_kontena=true")
      end
    end

    def execute
      return register_current if self.current?
      response = register(self.name, self.url, self.provider, self.redirect_uri, self.version, self.owner)
      if self.return?
        return response['data']['id']
      elsif self.id?
        puts response['data']['id']
      else
        puts "Registered master.".colorize(:green)
        puts "ID: #{response['data']['id']}"
        puts "Client ID: #{response['data']['attributes']['client-id']}"
        puts "Client Secret: #{response['data']['attributes']['client-secret']}"
      end
    end
  end
end
