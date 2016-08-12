require 'singleton'
require 'uri'
require 'jsonpath'
require 'httpclient'

require_relative '../helpers/config_helper'

# Authentication provider configuration and helpers.
#
# It loads initial values from configuration and can also save them back using .save
#
# Userinfo parsing in done through jsonpath http://goessner.net/articles/JsonPath/
# You can define multiple optional paths by adding multiple jsonpath queries separated with
# a semicolon, for example '$..username;$..login' will run two queries and use the first
# found value.
#
# When the user needs to authenticate with the auth provider, send a redirect header
# with location:
# AuthProvider.authorize_url(state: <app_generated_state>)
#
# When you want to fetch the userinfo for this user from the auth provider, you can use
# AuthProvider.get_userinfo(<access_token_of_the_user>)
#
# To exchange an authorization_code to a real actual access token, use 
# AuthProvider.get_token(<auth_code>)
class AuthProvider < OpenStruct
  include Singleton
  include ConfigHelper # adds a .config method

  # Minimum fields for authentication to work if by luck the defaults are ok
  REQUIRED_FIELDS = [
      :client_id, :client_secret, :authorize_endpoint,
      :token_endpoint, :userinfo_endpoint, :userinfo_scope
  ]

  # Initializes a new auth provider instance.
  def initialize
    # The table syntax is for initializing an OpenStruct.
    @table = {}
    @table[:client_id] = config[:oauth2_client_id]
    @table[:client_secret] = config[:oauth2_client_secret]
    @table[:authorize_endpoint] = config[:oauth2_authorize_endpoint]
    @table[:code_requires_basic_auth] = config[:oauth2_code_requires_basic_auth] || false
    @table[:token_endpoint] = config[:oauth2_token_endpoint]
    @table[:token_method] = config[:oauth2_token_method] || 'post'
    @table[:token_post_content_type] = config[:oauth2_token_post_content_type] || 'application/json'
    @table[:userinfo_scope] = config[:oauth2_userinfo_scope] || 'user:email'
    @table[:userinfo_endpoint] = config[:oauth2_userinfo_endpoint]
    @table[:userinfo_username_jsonpath] = config[:oauth2_userinfo_username_jsonpath] || '$..username;$..login'
    @table[:userinfo_email_jsonpath] = config[:oauth2_userinfo_email_jsonpath] || '$..email;$..emails;$..primary_email'
    @table[:userinfo_user_id_jsonpath] = config[:oauth2_userinfo_user_id_jsonpath] || '$..id;$..uid;$..userid,$..user_id'
  end

  # Saves the values back to configuration
  def save
    each_pair do |key, value|
      config[key] = value
    end
  end

  def missing_fields
    REQUIRED_FIELDS.select { |field| self[field].nil? }
  end

  # Returns true when all required fields have values. These are the minimum settings that
  # are required for the module to work.
  def valid?
    missing_fields.empty?
  end

  def callback_url
    @callback_url ||= config[:root_url].nil? ? nil : URI.join(config[:root_url], 'cb')
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
    ENV["DEBUG"] && puts("#{$!} #{$!.message}")
    nil
  end

  # Request userinfo from the authentication provider userinfo endpoint
  #
  # @param [String] access_token
  # @return [Hash] userinfo hash with :username, :id and :email
  def get_userinfo(access_token)
    uri = URI.parse(self.userinfo_endpoint)
    uri.path = uri.path.gsub(/\:access\_token/, access_token)
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
    ENV["DEBUG"] && puts("#{$!} #{$!.message}")
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
    ENV["DEBUG"] && puts("#{$!} #{$!.message}")
    nil
  end

  # Instance of HTTPClient
  #
  # @return [HTTPClient]
  def client
    @client ||= HTTPClient.new
  end

  # Defines forwarders for instance methods, so you can call AuthProvider.x instead of AuthProvider.instance.x
  class << self
    extend Forwardable
    def_delegators :instance, *AuthProvider.instance_methods(false)
  end
end
