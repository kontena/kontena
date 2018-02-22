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
    option ['--return'],  :flag, 'Return the ID', hidden: true
    option ['--force'],   :flag, "Don't ask questions"

    option ['--cloud-master-id'], '[ID]', "Use existing cloud master ID", hidden: true
    option ['--current'], :flag, 'Register and configure current master', hidden: true

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
      exit_with_error "Failed: #{response['error']}" if response['error']
      exit_with_error "Failed (no data)" unless response['data']
      response
    end

    def get_existing(id)
      cloud_client.get("user/masters/#{id}")
    end

    def cloud_masters
      masters = []
      spinner "Retrieving a list of your registered Kontena Masters in Kontena Cloud" do |spin|
        begin
          masters = Kontena.run!(%w(cloud master list --return --quiet))
        rescue SystemExit
          spin.fail
        end
      end
      masters
    end

    def new_cloud_master_name(master_name)
      masters = cloud_masters
      return master_name if masters.empty?

      existing_master = masters.find { |m| m['attributes']['name'] == master_name }
      return master_name unless existing_master

      new_name = "#{master_name}-2"
      new_name.succ! until masters.find { |m| m['attributes']['name'] == new_name }.nil?
      new_name
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
        puts "   (kontena master user invite old@email.example.com)"
        exit_with_error "Aborted" unless prompt.yes?("Proceed?")
      end

      new_name = new_cloud_master_name(current_master.name)

      if self.cloud_master_id
        response = spinner "Retrieving Master information from Kontena Cloud using id" do
          get_existing(self.cloud_master_id)
        end
        if response && response.kind_of?(Hash) && response.has_key?('data') && response['data']['attributes']
          if (self.provider && response['data']['attributes']['provider'] != self.provider) || (self.version && response['data']['attributes']['version'] != self.version)
            spinner "Updating provider and version attributes to Kontena Cloud master" do |spin|
              args = []
              args += ['--provider', self.provider] if self.provider
              args += ['--version', self.version] if self.version
              args << self.cloud_master_id
              spin.fail! unless Kontena.run(['cloud', 'master', 'update'] + args)
            end
          end
        end
      else
        response = spinner "Registering current Kontena Master '#{current_master.name}' #{" as '#{new_name}' " unless new_name == current_master.name}to Kontena Cloud" do
          register(new_name, current_master.url, self.provider, current_master.url.gsub(/\/$/, '') + "/cb", self.version)
        end
      end

      spinner "Loading Kontena Cloud auth provider base configuration to Kontena Master" do |spin|
        spin.fail! unless Kontena.run(%w(master config import --force --preset kontena_auth_provider))
      end

      spinner "Updating OAuth2 client-id and client-secret to Kontena Master" do |spin|
        spin.fail! unless Kontena.run(
          [
            'master', 'config', 'set',
            "oauth2.client_id=#{response['data']['attributes']['client-id'].shellescape}",
            "oauth2.client_secret=#{response['data']['attributes']['client-secret'].shellescape}",
            "server.root_url=#{current_master.url.shellescape}",
            "server.name=#{current_master.name.shellescape}",
            "cloud.provider_is_kontena=true"
          ]
        )
      end
    end

    def execute
      unless cloud_client.authentication_ok?(kontena_account.userinfo_endpoint)
        Kontena.run!(%w(cloud login))
        config.reset_instance
        reset_cloud_client
      end

      return register_current if self.current?

      exit_with_error 'Master name is required' unless self.name

      response = register(self.name, self.url, self.provider, self.redirect_uri, self.version, self.owner)
      if self.return?
        return response['data']['id']
      elsif self.id?
        puts response['data']['id']
      else
        puts pastel.green("Registered master.")
        puts "ID: #{response['data']['id']}"
        puts "Client ID: #{response['data']['attributes']['client-id']}"
        puts "Client Secret: #{response['data']['attributes']['client-secret']}"
      end
    end
  end
end
