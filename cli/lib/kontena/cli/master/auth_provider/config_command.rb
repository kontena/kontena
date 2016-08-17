require 'json'
require 'yaml'

module Kontena::Cli::Master::AuthProvider
  class ConfigCommand < Clamp::Command

    include Kontena::Cli::Common

    PRESETS = {
      github: {
        'authorize_endpoint'         => 'https://github.com/login/oauth/authorize',
        'code_requires_basic_auth'   => false,
        'token_endpoint'             => 'https://github.com/login/oauth/access_token',
        'token_method'               => 'post',
        'token_post_content_type'    => 'application/json',
        'userinfo_scope'             => 'user:email',
        'userinfo_endpoint'          => 'https://api.github.com/user',
        'userinfo_username_jsonpath' => '$..login',
        'userinfo_email_jsonpath'    => '$..email',
        'userinfo_user_id_jsonpath'  => '$..id'
      },
      kontena: {
      }
    }

    MINIMUM_SETTINGS = [
      'authorize_endpoint',
      'token_endpoint',
      'userinfo_endpoint',
      'userinfo_scope',
      'client_id',
      'client_secret'
    ]

    parameter "[FILENAME]", "Read configuration from json or yaml file"

    option ['-d', '--dump'], '[JSON|YAML]', "Print out the configuration and exit"

    option ['--preset'], '[NAME]', "Use preset provider configuration. Providers: #{PRESETS.keys.join(",")}"

    option ['--authorize_endpoint'], '[URL]', 'OAuth2 Authorization endpoint complete URL'
    option ['--token_endpoint'], '[URL]', 'OAuth2 Token endpoint complete URL'
    option ['--userinfo_endpoint'], '[URL]', 'Userinfo endpoint complete URL'
    option ['--userinfo_scope'], '[SCOPE]', 'Authorization scope for requesting basic user information'
    option ['--client_id'], '[CLIENT_ID]', 'OAuth2 application client id'
    option ['--client_secret'], '[CLIENT_SECRET]', 'OAuth2 application client secret'
    option ['--code_requires_basic_auth'], :flag, 'Authorization code exchange requires client_id:client_secret in authentication header'
    option ['--token_method'], '[GET|POST]', 'Authorization code exchange request HTTP method'
    option ['--token_post_content_type'], '[MIME]', 'Authorization code exchange request content mime type'
    option ['--userinfo_email_jsonpath'], '[JSONPATH]', 'JSONPath query for getting email address from userinfo response'
    option ['--userinfo_user_id_jsonpath'], '[JSONPATH]', 'JSONPath query for getting user id from userinfo response'
    option ['--userinfo_username_jsonpath'], '[JSONPATH]', 'JSONPath query for getting username from userinfo response'

    def execute
      require_current_master
      require_token

      if self.filename
        unless File.exist?(self.filename) && File.readable?(self.filename)
          puts "Could not read file #{self.filename}"
          exit 1
        end
        if self.filename.end_with?('.json')
          settings = JSON.parse(File.read(self.filename)).merge(config_from_params)
        elsif self.filename.end_with?('.yml')
          settings = YAML.load(File.read(self.filename)).merge(config_from_params)
        else
          puts "Could not determine filetype of #{filename} - must be .json or .yml"
          exit 1
        end
      elsif self.preset
        if PRESETS.has_key?(self.preset.to_sym)
          settings = PRESETS[self.preset.to_sym].merge(config_from_params)
        else
          puts 'Unknown provider preset name'
          exit 1
        end
      else
        settings = config_from_params
      end

      if !is_kontena?(settings) && (settings['client_id'].nil? || settings['client_secret'].nil?)
        puts "You must supply --client_id and --client_secret when using 3rd party authentication providers."
        puts
        puts "You should get them from the authentication provider after creating an OAuth2 application there."
        exit 1
      end

      if MINIMUM_SETTINGS.any? { |s| settings[s].nil? }
        puts "You need to supply at least these settings:"
        puts
        MINIMUM_SETTINGS.each { |s| puts "  --#{s}" }
        exit 1
      end

      case self.dump.to_s.downcase
      when 'json'
        puts JSON.pretty_generate(settings)
        exit
      when 'yaml', 'yml'
        puts YAML.dump(settings)
        exit
      else
        # do nothing
      end

      client = Kontena::Client.new(current_master.url, current_master.token)
      response = client.post('/v1/auth_provider', settings)
      if response && response.kind_of?(Hash)
        if response.has_key?('error')
          puts "Server reported an error: #{response['error']}"
          exit 1
        else
          unless !current_master.username == 'admin'
            puts "Authentication provider settings updated. You will have to authenticate again, use: kontena auth master"
            current_master.token = nil
            config.write
          end
        end
      end
    end

    def is_kontena?(settings)
      return true if settings['authorize_endpoint'] =~ /kontena\.io\//
      false
    end

    def config_from_params
      {
        'authorize_endpoint'         => self.authorize_endpoint,
        'client_id'                  => self.client_id,
        'client_secret'              => self.client_secret,
        'code_requires_basic_auth'   => self.code_requires_basic_auth?,
        'token_endpoint'             => self.token_endpoint,
        'token_method'               => self.token_method,
        'token_post_content_type'    => self.token_post_content_type,
        'userinfo_email_jsonpath'    => self.userinfo_email_jsonpath,
        'userinfo_endpoint'          => self.userinfo_endpoint,
        'userinfo_scope'             => self.userinfo_scope,
        'userinfo_user_id_jsonpath'  => self.userinfo_user_id_jsonpath,
        'userinfo_username_jsonpath' => self.userinfo_username_jsonpath
      }.reject{ |_, v| v.nil? }
    end
  end
end


