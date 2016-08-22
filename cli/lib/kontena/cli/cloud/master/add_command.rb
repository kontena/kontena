module Kontena::Cli::Cloud::Master
  class AddCommand < Kontena::Command

    include Kontena::Cli::Common

    callback_matcher 'cloud-master', 'create'

    requires_current_account_token

    parameter "NAME", "Master name"

    option ['--redirect-uri'], '[URL]',      'Se master redirect URL'
    option ['--url'],          '[URL]',      'Se master URL'
    option ['--provider'],     '[NAME]',     'Se master provider'
    option ['--name'],         '[NAME]',     'Se master name',        hidden: true
    option ['--version'],      '[VERSION]',  'Se master version',     hidden: true
    option ['--owner'],        '[NAME]',     'Se master owner',       hidden: true

    option ['--id'], :flag, 'Just output the ID'
    option ['--arg'], :flag, 'Output as command line arguments'

    option ['--return'], :flag, 'Return the ID', hidden: true

    def execute
      attributes = { 'name' => self.name }
      attributes['url'] = self.url if self.url
      attributes['provider'] = self.provider if self.provider
      attributes['redirect-uri'] = self.redirect_uri if self.redirect_uri
      attributes['version'] = self.version if self.version
      attributes['owner'] = self.owner if self.owner

      response = cloud_client.post('user/masters', { data: { attributes: attributes } })
      if response.kind_of?(Hash)
        if response['error']
          puts "Failed: #{response['error']}"
          exit 1
        else
          if self.return?
            return response['data']['id']
          elsif self.id?
            puts response['data']['id']
          elsif self.arg?
            puts "--client-id #{response['data']['attributes']['client-id']} --client-secret #{response['data']['attributes']['client-secret']}"
          else
            puts "Created master.".colorize(:green)
            puts "ID: #{response['data']['id']}"
            puts "Client ID: #{response['data']['attributes']['client-id']}"
            puts "Client Secret: #{response['data']['attributes']['client-secret']}"
          end
        end
      end
    end
  end
end
