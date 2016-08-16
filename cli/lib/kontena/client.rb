require 'json'
require 'excon'
require 'uri'
require 'base64'
require 'socket'
require 'openssl'
require 'uri'
require_relative 'errors'
require_relative 'cli/version'
require_relative 'cli/config'

module Kontena
  class Client

    CLIENT_ID     = ''
    CLIENT_SECRET = ''

    CONTENT_URLENCODED = 'application/x-www-form-urlencoded'.freeze
    CONTENT_JSON       = 'application/json'.freeze
    JSON_REGEX         = /application\/(.+?\+)?json/.freeze
    CONTENT_TYPE       = 'Content-Type'.freeze
    ACCEPT             = 'Accept'.freeze
    AUTHORIZATION      = 'Authorization'.freeze

    attr_accessor :default_headers
    attr_accessor :path_prefix
    attr_reader :http_client
    attr_reader :last_response
    attr_reader :options
    attr_reader :token
    attr_reader :logger
    attr_reader :api_url
    attr_reader :host

    # Initialize api client
    #
    # @param [String] api_url
    # @param [Hash] default_headers
    def initialize(api_url, token = {}, options = {})
      @api_url, @token, @options = api_url, token, options
      uri = URI.parse(@api_url)
      @host = uri.host
      @logger = Logger.new(STDOUT)
      @logger.level = ENV["DEBUG"] ? Logger::DEBUG : Logger::INFO
      @logger.progname = 'CLIENT'
      @options[:default_headers] ||= {}
      Excon.defaults[:ssl_verify_peer] = false if ignore_ssl_errors?
      @http_client = Excon.new(api_url, omit_default_port: true)
      @default_headers = {
        ACCEPT => CONTENT_JSON,
        CONTENT_TYPE => CONTENT_JSON,
        'User-Agent' => "kontena-cli/#{Kontena::Cli::VERSION}"
      }.merge(options[:default_headers])
      @path_prefix = options[:path_prefix] || '/v1/'
      logger.debug "Client initialized with api_url: #{@api_url} token: #{token.nil?.to_s} prefix: #{@path_prefix}"
    end

    def certificate_info
      return nil unless api_url.start_with?('https')
			tcp_client = TCPSocket.new(host, 443)
      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.cert_store = OpenSSL::X509::Store.new
      ssl_context.cert_store.set_default_paths
      ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
      ssl_context.ca_file = Excon.defaults[:ssl_ca_file] if Excon.defaults[:ssl_ca_file]
			ssl_client = OpenSSL::SSL::SSLSocket.new(tcp_client, ssl_context)
			ssl_client.connect
			cert = OpenSSL::X509::Certificate.new(ssl_client.peer_cert)
			ssl_client.sysclose
			tcp_client.close
				
			certprops = OpenSSL::X509::Name.new(cert.issuer).to_a
			issuer = certprops.select { |name, data, type| name == "O" }.first[1]
			{ 
				:valid_on => cert.not_before,
				:valid_until => cert.not_after,
				:issuer => issuer
			}
    rescue
      nil
    end

    def basic_auth_header
      {
        AUTHORIZATION => "Basic #{Base64.encode64([client_id, client_secret].join(':')).gsub(/[\r\n]/, '')}"
      }
    end

    def client_id
      ENV['KONTENA_CLIENT_ID'] || CLIENT_ID
    end

    def client_secret
      ENV['KONTENA_CLIENT_SECRET'] || CLIENT_SECRET
    end

    def authentication_ok?(token_verify_path)
      return false unless token
      return false unless token['access_token']
      return false unless token_verify_path
      logger.debug 'Authentication verification request token validations pass'
      final_path = token_verify_path.gsub(/\:access\_token/, token['access_token'])
      request(path: final_path)
      true
    rescue
      false
    end

    def code_login(code, auth_url)
      handle_login_response(
        request(
          http_method: :post,
          path: '/v1/token',
          query: { grant_type: 'code', code: code, url: auth_url },
          auth: false
        )
      )
    end

    # Handles token object update after login request.
    # Does not write configuration.
    def handle_login_response(response)
      response = {'error' => response} unless response.kind_of?(Hash)
      if response['access_token']
        if response['user']
          token.username = response['user']['username'] || response['user']['email']
        end
        token['access_token']  = response['access_token']
        token['refresh_token'] = response['refresh_token']
        token['expires_at']    = in_to_at(response['expires_in'])
        true
      else
        logger.debug "Login failure: #{response['error']}"
        false
      end
    end

    # Build user credentials login request parameters.
    def password_login_params(email, password, scope=nil)
      {
          username: email,
          password: password,
          grant_type: 'password',
          scope: scope || 'user'
      }
    end

    # Perform user credentials login to auth provider.
    #
    # @param [String] username
    # @param [String] password
    # @param [String] path_to_login_endpoint
    def login(email, password, login_path, use_basic: false)
      return false unless token
      return false unless token.respond_to?(:config)
      token.access_token = nil # reset token

      handle_login_response(
        request(
          http_method: :post,
          path: login_path,
          body: password_login_params(email, password),
          headers: { CONTENT_TYPE => CONTENT_JSON, ACCEPT => CONTENT_JSON }.merge(
            use_basic ? basic_auth_header : {}
          ),
          expects: [200, 201, 400, 401, 403]
        )
      )
    end

    # Return server version from a Kontena master
    #
    # @return [String] version_string
    def server_version
      request(auth: false, expects: 200)['version']
    rescue
      logger.debug "Server version exception: #{$!} #{$!.message}"
      nil
    end

    # Get request
    #
    # @param [String] path
    # @param [Hash,NilClass] params
    # @param [Hash] headers
    # @return [Hash]
    def get(path, params = nil, headers = {})
      request(path: path, query: params, headers: headers)
    end

    # Post request
    #
    # @param [String] path
    # @param [Object] obj
    # @param [Hash] params
    # @param [Hash] headers
    # @return [Hash]
    def post(path, obj, params = {}, headers = {})
      request(http_method: :post, path: path, body: obj, query: params, headers: headers)
    end

    # Put request
    #
    # @param [String] path
    # @param [Object] obj
    # @param [Hash] params
    # @param [Hash] headers
    # @return [Hash]
    def put(path, obj, params = {}, headers = {})
      request(http_method: :put, path: path, body: obj, query: params, headers: headers)
    end

    # Delete request
    #
    # @param [String] path
    # @param [Hash,String] body
    # @param [Hash] params
    # @param [Hash] headers
    # @return [Hash]
    def delete(path, body = nil, params = {}, headers = {})
      request(http_method: :delete, path: path, body: body, query: params, headers: headers)
    end

    # Get stream request
    #
    # @param [String] path
    # @param [Lambda] response_block
    # @param [Hash,NilClass] params
    # @param [Hash] headers
    def get_stream(path, response_block, params = nil, headers = {})
      request(path: path, query: params, headers: headers, response_block: response_block)
    end

    # Perform a HTTP request. Will try to refresh the access token if it's
    # expired or if the server responds with HTTP 401.
    #
    # @param http_method [Symbol] :get, :post, etc
    # @param path [String] if it starts with / then prefix won't be used.
    # @param body [Hash, String] will be encoded using #encode_body
    # @param query [Hash] url query parameters
    # @param headers [Hash] extra headers for request.
    # @param response_block [Proc] for streaming requests, must respond to #call
    # @param expects [Array] raises unless response status code matches this list.
    # @param auth [Boolean] use token authentication default = true
    # @return [Hash, String] response parsed response object
    def request(http_method: :get, path:'/', body: nil, query: {}, headers: {}, response_block: nil, expects: [200, 201], auth: true)
      retried ||= false
      if auth && token && token.respond_to?(:expired?) && token.expired?
        raise Excon::Errors::Unauthorized, 'Token expired or not valid, you need to login again, use: kontena login'
      end
      request_headers = request_headers(headers, auth)
      body_content = body.nil? ? '' : encode_body(body, request_headers[CONTENT_TYPE])
      request_headers.merge!('Content-Length' => body_content.bytesize)
      request_options = {
          method: http_method,
          expects: Array(expects),
          path: path.start_with?('/') ? path : request_uri(path),
          headers: request_headers,
          body: body_content,
          query: query
      }
      request_options.merge!(response_block: response_block) if response_block
      @last_response = http_client.request(request_options)
      parse_response
    rescue Excon::Errors::Unauthorized
      logger.debug 'Access token expired'
      if retried || !token.respond_to?(:config)
        raise Kontena::Errors::StandardError.new(401, 'The access token has expired and needs to be refreshed')
      end
      retried = true
      retry if refresh_token
      handle_error_response
    rescue Excon::Errors::NotFound
      raise Kontena::Errors::StandardError.new(404, 'Not found')
    rescue Excon::Errors::Forbidden
      raise Kontena::Errors::StandardError.new(403, 'Access denied')
    rescue
      logger.debug "Request exception: #{$!} - #{$!.message}\n#{$!.backtrace.join("\n")}"
      handle_error_response
    end

    # Request a code from auth provider.
    def generate_code(authorization_path, scopes = nil, expires_in = nil, note = nil)
      generate_token(authorization_path, 'code', scopes, expires_in, note)
    end

    # Request a token from auth provider
    def generate_token(authorization_path, response_type, scopes = nil, expires_in = nil, note = nil)
      return false unless token
      response = request(
        http_method: :post,
        path: authorization_path,
        body: {
          #client_id: ENV['KONTENA_CLIENT_ID'] || CLIENT_ID,
          #client_secret: ENV['KONTENA_CLIENT_SECRET'] || CLIENT_SECRET,
          note: note,
          response_type: response_type,
          expires_in: expires_in,
          scopes: scopes || []
        },
      )
      response && response['code']
    end

    # Determine refresh_token request path from token object data
    #
    # @return [String]
    def token_refresh_path
      if token.respond_to?(:parent) && token.parent.respond_to?(:account) && token.respond_to?(:config)
        token.config.find_account(token.parent.account).token_endpoint
      elsif token.respond_to?(:parent)
        token.parent.token_endpoint
      end
    end

    # Build a token refresh request param hash
    #
    # @return [Hash]
    def refresh_request_params
      {
        refresh_token: token['refresh_token'],
        grant_type: 'refresh_token'
        #client_id: ENV['KONTENA_CLIENT_ID'] || CLIENT_ID,
        #client_secret: ENV['KONTENA_CLIENT_SECRET'] || CLIENT_SECRET
      }
    end

    # Perform refresh token request to auth provider.
    # Updates the client's Token object and writes changes to 
    # configuration.
    #
    # @return [Boolean] success?
    def refresh_token
      logger.debug "Performing token refresh"
      return false if token.nil?
      return false if token['refresh_token'].nil?
      path = token_refresh_path
      logger.debug "Token refresh url: #{api_url} path: #{path || 'unknown'}"
      return false unless path
      logger.debug "Client token validations pass"
      response = request(
        http_method: :post,
        path: path,
        body: refresh_request_params,
        headers: { CONTENT_TYPE => CONTENT_URLENCODED }.merge(basic_auth_header),
        expects: [200, 201, 400, 401, 403],
        auth: false
      )
      if response && response['access_token']
        logger.debug "Got response to refresh request"
        token.access_token  = response['access_token']
        token.refresh_token = response['refresh_token']
        token.expires_at = in_to_at(response['expires_in'])
        token.config && token.config.write
        true
      else 
        logger.debug "Got null or bad response to refresh request: #{last_response.inspect}"
        false
      end
    rescue
      logger.debug "Access token refresh exception: #{$!} - #{$!.message}"
      false
    end

    private

    ##
    # Get full request uri
    #
    # @param [String] path
    # @return [String]
    def request_uri(path)
      "#{path_prefix}#{path}"
    end

    def bearer_authorization_header
      if token && token['access_token']
        {AUTHORIZATION => "Bearer #{token['access_token']}"}
      else
        {}
      end
    end

    ##
    # Build request headers. Removes empty headers.
    # @example
    #   request_headers('Authorization' => nil)
    #
    # @param [Hash] headers
    # @return [Hash]
    def request_headers(headers = {}, auth = true)
      headers = default_headers.merge(headers)
      headers.merge!(bearer_authorization_header) if auth
      headers.reject{|_,v| v.nil? || (v.respond_to?(:empty?) && v.empty?)}
    end

    ##
    # Encode body based on content type.
    #
    # @param [Object] body
    # @param [String] content_type
    # @return [String] encoded_content
    def encode_body(body, content_type)
      if content_type =~ JSON_REGEX # vnd.api+json should pass as json
        dump_json(body)
      elsif content_type == CONTENT_URLENCODED && body.kind_of?(Hash)
        URI.encode_www_form(body)
      else
        body
      end
    end

    ##
    # Parse response. If the respons is JSON, returns a Hash representation.
    # Otherwise returns the raw body.
    #
    # @param [HTTP::Message]
    # @return [Hash,String]
    def parse_response
      if last_response.headers[CONTENT_TYPE] =~ JSON_REGEX
        parse_json(last_response.body)
      else
        last_response.body
      end
    end

    ##
    # Parse json
    #
    # @param [String] json
    # @return [Hash,Object,NilClass]
    def parse_json(json)
      JSON.parse(json)
    rescue
      logger.debug "JSON parse exception: #{$!} : #{$!.message}"
      nil
    end

    ##
    # Dump json
    #
    # @param [Object] obj
    # @return [String]
    def dump_json(obj)
      JSON.dump(obj)
    end

    # @return [Boolean]
    def ignore_ssl_errors?
      ENV['SSL_IGNORE_ERRORS'] == 'true'
    end

    # @param [Excon::Response] response
    def handle_error_response
      raise $!, $!.message unless last_response
      raise Kontena::Errors::StandardError.new(last_response.status, last_response.body)
    end

    # Convert expires_in into expires_at
    #
    # @param [Fixnum] seconds_till_expiration
    # @return [Fixnum] expires_at_unix_timestamp
    def in_to_at(expires_in)
      if expires_in.to_i < 1
        0
      else
        Time.now.utc.to_i + expires_in.to_i
      end
    end
  end
end
