module Kontena::Cli::Cloud::Master
  class UpdateCommand < Kontena::Command

    include Kontena::Cli::Common

    callback_matcher 'cloud-master', 'update'

    requires_current_account_token

    parameter "MASTER_ID", "Master ID"

    option ['--redirect-uri'], '[URL]',      'Set master redirect URL'
    option ['--url'],          '[URL]',      'Set master URL'
    option ['--provider'],     '[NAME]',     'Set master provider'
    option ['--name'],         '[NAME]',     'Set master name',        hidden: true
    option ['--version'],      '[VERSION]',  'Set master version',     hidden: true
    option ['--owner'],        '[NAME]',     'Set master owner',       hidden: true

    def get_attributes
      cloud_client.get("user/masters/#{self.master_id}")["data"]["attributes"]
    rescue
      nil
    end

    def execute
      attrs = get_attributes
      unless attrs
        puts pastel.red("Failed to obtain master credentials")
        exit 1
      end

      attrs["name"]         = self.name         if self.name
      attrs["redirect-uri"] = self.redirect_uri if self.redirect_uri
      attrs["url"]          = self.url          if self.url
      attrs["provider"]     = self.provider     if self.provider
      attrs["version"]      = self.version      if self.version
      attrs["owner"]        = self.owner        if self.owner

      response = cloud_client.put(
        "user/masters/#{master_id}",
        { data: { attributes: attrs.reject{ |k, _| ['client-id', 'client-secret'].include?(k) } } }
      )

      if response
        puts "Master settings updated"
      else
        puts "Request failed"
        exit 1
      end
    end
  end
end
