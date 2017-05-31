# Authentication provider configuration and helpers.
#
# Userinfo parsing in done through jsonpath :
#   http://goessner.net/articles/JsonPath/
#
# You can define multiple optional jsonpaths and separate them with a
# semicolon.  For example '$..username;$..login' will run two queries and use
# the first value it finds.
#
# When redirecting a user to auth provider's authorization url, use:
#   Location: auth_provider.authorize_url(state: <app_generated_state>)
#
# When you want to fetch the userinfo for this user from the auth provider,
# use:
#   auth_provider.get_userinfo(<access_token_of_the_user>)
#
# To exchange an authorization_code to a real actual access token, use
#   auth_provider.get_token(<auth_code>)
require 'uri'
require 'jsonpath'
require 'httpclient'

class AuthProvider
  include Logging

  # Minimum fields for authentication to work if by luck the defaults are ok
  REQUIRED_FIELDS = [
      :client_id, :client_secret, :authorize_endpoint,
      :token_endpoint, :userinfo_endpoint, :userinfo_scope,
      :root_url
  ]

  attr_accessor :client_id
  attr_accessor :client_secret
  attr_accessor :authorize_endpoint
  attr_accessor :code_requires_basic_auth
  attr_accessor :token_endpoint
  attr_accessor :token_method
  attr_accessor :token_post_content_type
  attr_accessor :userinfo_scope
  attr_accessor :userinfo_endpoint
  attr_accessor :userinfo_username_jsonpath
  attr_accessor :userinfo_email_jsonpath
  attr_accessor :userinfo_user_id_jsonpath
  attr_accessor :root_url
  attr_accessor :cloud_api_url
  attr_accessor :ignore_invalid_ssl
  attr_accessor :provider_is_kontena
  attr_accessor :uuid

  def self.instance
    new(Configuration.decrypt_all)
  end

  # Initializes a new auth provider instance.
  def initialize(config)
    @client_id = config['oauth2.client_id']
    @client_secret = config['oauth2.client_secret']
    @authorize_endpoint = config['oauth2.authorize_endpoint']
    @code_requires_basic_auth = config['oauth2.code_requires_basic_auth'].to_s == 'true'
    @token_endpoint = config['oauth2.token_endpoint']
    @token_method = config['oauth2.token_method'] || 'post'
    @token_post_content_type = config['oauth2.token_post_content_type'] || 'application/json'
    @userinfo_scope = config['oauth2.userinfo_scope'] || 'user:email'
    @userinfo_endpoint = config['oauth2.userinfo_endpoint']
    @userinfo_username_jsonpath = config['oauth2.userinfo_username_jsonpath'] || '$..username;$..login'
    @userinfo_email_jsonpath = config['oauth2.userinfo_email_jsonpath'] || '$..email;$..emails;$..primary_email'
    @userinfo_user_id_jsonpath = config['oauth2.userinfo_user_id_jsonpath'] || '$..id;$..uid;$..userid,$..user_id'
    @root_url = config['server.root_url']
    @cloud_api_url = config['cloud.api_url'] || 'https://cloud-api.kontena.io'
    @ignore_invalid_ssl = config['cloud.ignore_invalid_ssl'].to_s == 'true'
    @provider_is_kontena = config['cloud.provider_is_kontena'].to_s == "true"
    @uuid = config['server.uuid']
  end

  def is_kontena?
    return true if self.provider_is_kontena
    uri = URI.parse(self.authorize_endpoint) rescue nil
    uri && uri.host.end_with?('kontena.io')
  end

  def update_kontena
    return unless is_kontena?
    return unless valid?
    return unless master_access_token

    debug { "Updating master information to Kontena Cloud" }

    uri = URI.parse(self.cloud_api_url) rescue nil
    return unless uri

    uri.path = '/master'

    client = http_client
    if self.ignore_invalid_ssl
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    body = {
      data: {
        attributes: {          
          'redirect-uri' => callback_url,
          'url'          => self.root_url,
          'uuid'         => self.uuid
        }
      }
    }
    debug { "Master info: #{body[:attributes].inspect}" }
    response = client.request(
      :put,
      uri.to_s,
      header: {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        'Authorization' => "Bearer #{master_access_token}"
      },
      body: body.to_json
    )
  rescue => ex
    ex.message.gsub!(master_access_token, '<master_access_token>')
    error ex
  end

  def master_access_token
    unless @master_access_token
      response = request_master_access_token
      if response.status == 200
        json_response = JSON.parse(response.body)
        @master_access_token = json_response['access_token'] if json_response
      end
    end
    @master_access_token
  rescue => ex
    error ex
  end

  def http_client
    if ENV['DEBUG']
      HTTPClient.class_exec { def debug_dev; STDOUT; end }
    end
    HTTPClient.new
  end

  def request_master_access_token
    client = http_client

    body = {
      grant_type: 'client_credentials',
      client_id: self.client_id,
      client_secret: self.client_secret
    }
    debug { "Requesting master access token from Kontena Cloud" }
    client.request(
      :post,
      self.token_endpoint,
      header: {
        'Content-Type' => 'application/x-www-form-urlencoded',
        'Accept' => 'application/json'
      },
      body: body
    )
  rescue => ex
    error ex
  end

  def missing_fields
    REQUIRED_FIELDS.select { |field| self.send(field).nil? || self.send(field).strip == "" }
  end

  # Returns true when all required fields have values. These are the minimum settings that
  # are required for the module to work.
  def valid?
    return true if missing_fields.empty?
    debug { "Auth provider not valid, missing fields: #{missing_fields.join(',')}" }
    false
  end

  def callback_url
    self.root_url.nil? ? nil : URI.join(self.root_url, 'cb').to_s
  end

  # URL to the authentication provider authorization endpoint
  def authorize_url(state: nil, scope: nil)
    uri = URI.parse(self.authorize_endpoint)
    uri.query = URI.encode_www_form(
      {
        response_type: 'code',
        client_id:     client_id,
        scope:         scope || userinfo_scope,
        state:         state,
        redirect_uri:  callback_url
      }.reject {|_,v| v.nil? }
    )
    uri.to_s
  rescue => ex
    error ex
  end

  # Exchange an authorization code for an access_token and usually refresh_token + expires_in
  #
  # @param [String] authorization_code
  # @return [Hash] token
  def get_token(code)
    token_method = self.token_method.to_s.downcase == 'post' ? :post : :get

    request_params = {
      grant_type: 'authorization_code',
      code: code,
      client_id: self.client_id,
      client_secret: self.client_secret,
      redirect_uri:  callback_url
    }

    if token_method == :post
      body = self.token_post_content_type.include?('json') ? request_params.to_json : URI.encode_www_form(request_params)
      query = nil
    else
      body = nil
      query = URI.encode_www_form(request_params)
    end

    client = http_client
    if self.ignore_invalid_ssl
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    if self.code_requires_basic_auth
      client.set_auth(nil, self.client_id, self.client_secret)
      client.force_basic_auth = true
    end

    headers = { 'Accept' => 'application/json' }
    headers['Content-Type'] = self.token_post_content_type unless token_method == :get

    response = client.request(
      token_method,
      self.token_endpoint,
      follow_redirect: false,
      header: headers,
      body: body,
      query: query
    )

    client.set_auth(nil, nil, nil)
    client.force_basic_auth = false

    if response.headers['Content-Type'].to_s.include?('json')
      JSON.parse(response.body)
    elsif response.headers['Content-Type'].to_s.include?('urlencoded')
      URI.decode_www_form(response.body)
    else
      nil
    end
  rescue => ex
    ex.message.gsub!(self.client_secret, '<client_secret>') if self.client_secret
    ex.message.gsub!(code, '<authorization_code>') if code
    error ex
    nil
  end

  # Request userinfo from the authentication provider userinfo endpoint
  #
  # @param [String] access_token
  # @return [Hash] userinfo hash with :username, :id and :email
  def get_userinfo(access_token)
    uri = URI.parse(self.userinfo_endpoint)
    uri.path = uri.path.gsub(/\:access\_token/, access_token)
    client = http_client
    if self.ignore_invalid_ssl
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    response = client.request(
      :get,
      uri.to_s,
      header: {
        'Accept' => 'application/json',
        'Authorization' => "Bearer #{access_token}"
      }
    )

    result = {}

    if response && response.headers['Content-Type'].to_s.include?('json')
      result[:username] = jsonpath_query(response.body, self.userinfo_username_jsonpath)
      result[:id] = jsonpath_query(response.body, self.userinfo_user_id_jsonpath)
      result[:email] = jsonpath_query(response.body, self.userinfo_email_jsonpath)
    end

    result
  rescue => ex
    ex.message.gsub!(access_token, '<access_token>') if access_token
    error ex
    nil
  end

  # Run a JSONPath-query on a JSON, returns the first hit, even if result is an array.
  #
  # @param [String] json
  # @param [String] json_path can also be a list of jsonpaths separated by a semicolon
  # @return [Object] should be a string or an integer to work
  def jsonpath_query(json, jsonpath)
    jsonpath.split(';').each do |jsonpath|
      result = Array(JsonPath.on(json, jsonpath))
      unless result.empty?
        return Array(result.first).first
      end
    end
    nil
  rescue => ex
    error ex
    nil
  end
end
