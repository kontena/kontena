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
#   Location: AuthProvider.authorize_url(state: <app_generated_state>)
#
# When you want to fetch the userinfo for this user from the auth provider,
# use:
#   AuthProvider.get_userinfo(<access_token_of_the_user>)
#
# To exchange an authorization_code to a real actual access token, use
#   AuthProvider.get_token(<auth_code>)
require 'singleton'
require 'uri'
require 'jsonpath'
require 'httpclient'

require_relative '../helpers/config_helper'

class AuthProvider < OpenStruct
  include Singleton
  include ConfigHelper # adds a .config method
  include Logging

  # Minimum fields for authentication to work if by luck the defaults are ok
  REQUIRED_FIELDS = [
      :client_id, :client_secret, :authorize_endpoint,
      :token_endpoint, :userinfo_endpoint, :userinfo_scope,
      :root_url
  ]

  def self.reset_instance
    Singleton.send :__init__, self
    self
  end

  # Initializes a new auth provider instance.
  def initialize
    # The table syntax is for initializing an OpenStruct.
    @table = {}
    @table[:client_id] = config['oauth2.client_id']
    @table[:client_secret] = config['oauth2.client_secret']
    @table[:authorize_endpoint] = config['oauth2.authorize_endpoint']
    @table[:code_requires_basic_auth] = config['oauth2.code_requires_basic_auth'] || false
    if @table[:code_requires_basic_auth].kind_of?(String)
      @table[:code_requires_basic_auth] = @table[:code_requires_basic_auth] == "true"
    end
    @table[:token_endpoint] = config['oauth2.token_endpoint']
    @table[:token_method] = config['oauth2.token_method'] || 'post'
    @table[:token_post_content_type] = config['oauth2.token_post_content_type'] || 'application/json'
    @table[:userinfo_scope] = config['oauth2.userinfo_scope'] || 'user:email'
    @table[:userinfo_endpoint] = config['oauth2.userinfo_endpoint']
    @table[:userinfo_username_jsonpath] = config['oauth2.userinfo_username_jsonpath'] || '$..username;$..login'
    @table[:userinfo_email_jsonpath] = config['oauth2.userinfo_email_jsonpath'] || '$..email;$..emails;$..primary_email'
    @table[:userinfo_user_id_jsonpath] = config['oauth2.userinfo_user_id_jsonpath'] || '$..id;$..uid;$..userid,$..user_id'
    @table[:root_url] = config['server.root_url']
  end

  def is_kontena?
    return false unless self[:authorize_endpoint]
    config['cloud.provider_is_kontena'].to_s == "true" || URI.parse(self[:authorize_endpoint]).host.end_with?('kontena.io')
  end

  def update_kontena
    return unless is_kontena?
    return unless valid?

    uri = URI.parse(config['cloud.api_url'] || "https://cloud-api.kontena.io")
    uri.path = '/master'

    client = HTTPClient.new
    if config['cloud.ignore_invalid_ssl'].to_s == 'true'
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    client.set_auth(nil, self.client_id, self.client_secret)
    client.force_basic_auth = true

    body = {
      data: {
        attributes: {
          'redirect-uri' => callback_url,
          'url'          => self.root_url
        }
      }
    }

    response = client.request(
      :put,
      uri.to_s,
      header: {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      },
      body: body.to_json
    )
  end

  def missing_fields
    REQUIRED_FIELDS.select { |field| self[field].nil? || self[field].strip == "" }
  end

  # Returns true when all required fields have values. These are the minimum settings that
  # are required for the module to work.
  def valid?
    missing_fields.empty?
  end

  def callback_url
    @callback_url ||= self.root_url.nil? ? nil : URI.join(self.root_url, 'cb')
  end

  # URL to the authentication provider authorization endpoint
  def authorize_url(state: nil, scope: nil)
    uri = URI.parse(self[:authorize_endpoint])
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
      client_secret: self.client_secret
    }

    if token_method == :post
      body = self.token_post_content_type.include?('json') ? request_params.to_json : URI.encode_www_form(request_params)
      query = nil
    else
      body = nil
      query = URI.encode_www_form(request_params)
    end

    client = HTTPClient.new
    if config['oauth2.ignore_invalid_ssl'].to_s == 'true'
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    if self.code_requires_basic_auth
      client.set_auth(nil, self.client_id, self.client_secret)
      client.force_basic_auth = true
    end

    response = client.request(
      token_method,
      self.token_endpoint,
      follow_redirect: false,
      header: {
        'Accept' => 'application/json',
        'Content-Type' => self.token_post_content_type
      },
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
  rescue
    debug "#{$!} #{$!.message}"
    nil
  end

  # Request userinfo from the authentication provider userinfo endpoint
  #
  # @param [String] access_token
  # @return [Hash] userinfo hash with :username, :id and :email
  def get_userinfo(access_token)
    uri = URI.parse(self.userinfo_endpoint)
    uri.path = uri.path.gsub(/\:access\_token/, access_token)
    client = HTTPClient.new
    if config['oauth2.ignore_invalid_ssl'].to_s == 'true'
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
  rescue
    debug "#{$!} #{$!.message}"
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
  rescue
    debug "#{$!} #{$!.message}"
    nil
  end

  # Defines forwarders for instance methods, so you can call AuthProvider.x instead of AuthProvider.instance.x
  class << self
    extend Forwardable
    def_delegators :instance, *AuthProvider.instance_methods(false)
  end
end
