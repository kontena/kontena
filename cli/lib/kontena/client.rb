require 'json'
require 'excon'
require 'uri'
require 'base64'
require 'socket'
require 'openssl'
require 'uri'
require 'time'
require_relative 'errors'
require_relative 'cli/version'
begin
  require_relative 'cli/config'
rescue LoadError
end

module Kontena
  class Client

    CLIENT_ID     = ENV['KONTENA_CLIENT_ID']     || '15faec8a7a9b4f1e8b7daebb1307f1d8'.freeze
    CLIENT_SECRET = ENV['KONTENA_CLIENT_SECRET'] || 'fb8942ae00da4c7b8d5a1898effc742f'.freeze

    CONTENT_URLENCODED = 'application/x-www-form-urlencoded'.freeze
    CONTENT_JSON       = 'application/json'.freeze
    JSON_REGEX         = /application\/(.+?\+)?json/.freeze
    CONTENT_TYPE       = 'Content-Type'.freeze
    X_KONTENA_VERSION  = 'X-Kontena-Version'.freeze
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
    # @param [Kontena::Cli::Config::Token,Hash] access_token
    # @param [Hash] options
    def initialize(api_url, token = nil, options = {})
      @api_url, @token, @options = api_url, token, options
      uri = URI.parse(@api_url)
      @host = uri.host

      @logger = Logger.new(ENV["DEBUG"] ? $stderr : $stdout)
      @logger.level = ENV["DEBUG"].nil? ? Logger::INFO : Logger::DEBUG
      @logger.progname = 'CLIENT'

      @options[:default_headers] ||= {}

      excon_opts = {
        omit_default_port: true,
        connect_timeout: ENV["EXCON_CONNECT_TIMEOUT"] ? ENV["EXCON_CONNECT_TIMEOUT"].to_i : 5,
        read_timeout:    ENV["EXCON_READ_TIMEOUT"]    ? ENV["EXCON_READ_TIMEOUT"].to_i    : 30,
        write_timeout:   ENV["EXCON_WRITE_TIMEOUT"]   ? ENV["EXCON_WRITE_TIMEOUT"].to_i   : 5,
        ssl_verify_peer: ignore_ssl_errors? ? false : true
      }
      if ENV["DEBUG"]
        require_relative 'debug_instrumentor'
        excon_opts[:instrumentor] = Kontena::DebugInstrumentor
      end

      cert_file = File.join(Dir.home, "/.kontena/certs/#{uri.host}.pem")
      if File.exist?(cert_file) && File.readable?(cert_file)
        excon_opts[:ssl_ca_file] = cert_file
        key = OpenSSL::X509::Certificate.new(File.read(cert_file))
        if key.issuer.to_s == "/C=FI/O=Test/OU=Test/CN=Test"
          logger.debug "Key looks like a self-signed cert made by Kontena CLI, setting verify_peer_host to 'Test'"
          excon_opts[:ssl_verify_peer_host] = 'Test'
        end
      end

      logger.debug "Excon opts: #{excon_opts.inspect}"

      @http_client = Excon.new(api_url, excon_opts)

      @default_headers = {
        ACCEPT => CONTENT_JSON,
        CONTENT_TYPE => CONTENT_JSON,
        'User-Agent' => "kontena-cli/#{Kontena::Cli::VERSION}"
      }.merge(options[:default_headers])

      if token
        if token.kind_of?(String)
          @token = { 'access_token' => token }
        else
          @token = token
        end
        @default_headers.merge!('Authorization' => "Bearer #{@token['access_token']}")
      end

      @api_url = api_url
      @path_prefix = options[:prefix] || '/v1/'
    end

    # Generates a header hash for HTTP basic authentication.
    # Defaults to using client_id and client_secret as user/pass
    #
    # @param [String] username
    # @param [String] password
    # @return [Hash] auth_header_hash
    def basic_auth_header(user = nil, pass = nil)
      user ||= client_id
      pass ||= client_secret
      {
        AUTHORIZATION =>
          "Basic #{Base64.encode64([user, pass].join(':')).gsub(/[\r\n]/, '')}"
      }
    end

    # Generates a bearer token authentication header hash if a token object is
    # available. Otherwise returns an empty hash.
    #
    # @return [Hash] authentication_header
    def bearer_authorization_header
      if token && token['access_token']
        {AUTHORIZATION => "Bearer #{token['access_token']}"}
      else
        {}
      end
    end

    # Requests path supplied as argument and returns true if the request was a success.
    # For checking if the current authentication is valid.
    #
    # @param [String] token_verify_path a path that requires authentication
    # @return [Boolean]
    def authentication_ok?(token_verify_path)
      return false unless token
      return false unless token['access_token']
      return false unless token_verify_path

      final_path = token_verify_path.gsub(/\:access\_token/, token['access_token'])
      logger.debug "Requesting user info from #{final_path}"
      request(path: final_path)
      true
    rescue => ex
      logger.debug "Authentication verification exception: #{ex.class.name} : #{ex.message}\n#{ex.backtrace.join("\n  ")}"
      false
    end

    # Calls the code exchange endpoint in token's config to exchange an authorization_code
    # to a access_token
    def exchange_code(code)
      return nil unless token_account
      return nil unless token_account['token_endpoint']

      response = request(
        http_method: token_account['token_method'].downcase.to_sym,
        path: token_account['token_endpoint'],
        headers: { CONTENT_TYPE => token_account['token_post_content_type'] },
        body: {
          'grant_type' => 'authorization_code',
          'code' => code,
          'client_id' => Kontena::Client::CLIENT_ID,
          'client_secret' => Kontena::Client::CLIENT_SECRET
        },
        expects: [200,201],
        auth: false
      )
      response['expires_at'] ||= in_to_at(response['expires_in'])
      response
    end

    # Return server version from a Kontena master by requesting '/'
    #
    # @return [String] version_string
    def server_version
      request(auth: false, expects: 200)['version']
    rescue => ex
      logger.debug "Server version exception: #{ex.class.name} : #{ex.message}\n#{ex.backtrace.join("\n  ")}"
      nil
    end

    # OAuth2 client_id from ENV KONTENA_CLIENT_ID or client CLIENT_ID constant
    #
    # @return [String]
    def client_id
      ENV['KONTENA_CLIENT_ID'] || CLIENT_ID
    end

    # OAuth2 client_secret from ENV KONTENA_CLIENT_SECRET or client CLIENT_SECRET constant
    #
    # @return [String]
    def client_secret
      ENV['KONTENA_CLIENT_SECRET'] || CLIENT_SECRET
    end

    # Get request
    #
    # @param [String] path
    # @param [Hash,NilClass] params
    # @param [Hash] headers
    # @return [Hash]
    def get(path, params = nil, headers = {}, auth = true)
      request(path: path, query: params, headers: headers, auth: auth)
    end

    # Post request
    #
    # @param [String] path
    # @param [Object] obj
    # @param [Hash] params
    # @param [Hash] headers
    # @return [Hash]
    def post(path, obj, params = {}, headers = {}, auth = true)
      request(http_method: :post, path: path, body: obj, query: params, headers: headers, auth: auth)
    end

    # Put request
    #
    # @param [String] path
    # @param [Object] obj
    # @param [Hash] params
    # @param [Hash] headers
    # @return [Hash]
    def put(path, obj, params = {}, headers = {}, auth = true)
      request(http_method: :put, path: path, body: obj, query: params, headers: headers, auth: auth)
    end

    # Patch request
    #
    # @param [String] path
    # @param [Object] obj
    # @param [Hash] params
    # @param [Hash] headers
    # @return [Hash]
    def patch(path, obj, params = {}, headers = {}, auth = true)
      request(http_method: :patch, path: path, body: obj, query: params, headers: headers, auth: auth)
    end

    # Delete request
    #
    # @param [String] path
    # @param [Hash,String] body
    # @param [Hash] params
    # @param [Hash] headers
    # @return [Hash]
    def delete(path, body = nil, params = {}, headers = {}, auth = true)
      request(http_method: :delete, path: path, body: body, query: params, headers: headers, auth: auth)
    end

    # Get stream request
    #
    # @param [String] path
    # @param [Lambda] response_block
    # @param [Hash,NilClass] params
    # @param [Hash] headers
    def get_stream(path, response_block, params = nil, headers = {}, auth = true)
      request(path: path, query: params, headers: headers, response_block: response_block, auth: auth)
    end

    def token_expired?
      return false unless token
      if token.respond_to?(:expired?)
        token.expired?
      elsif token['expires_at'].to_i > 0
        token['expires_at'].to_i < Time.now.utc.to_i
      else
        false
      end
    end

    # Perform a HTTP request. Will try to refresh the access token and retry if it's
    # expired or if the server responds with HTTP 401.
    #
    # Automatically parses a JSON response into a hash.
    #
    # After the request has been performed, the response can be inspected using
    # client.last_response.
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
    def request(http_method: :get, path:'/', body: nil, query: {}, headers: {}, response_block: nil, expects: [200, 201, 204], host: nil, port: nil, auth: true)

      retried ||= false

      if auth && token_expired?
        raise Excon::Errors::Unauthorized, "Token expired or not valid, you need to login again, use: kontena #{token_is_for_master? ? "master" : "cloud"} login"
      end

      request_headers = request_headers(headers, auth)

      if body.nil?
        body_content = ''
        request_headers.delete(CONTENT_TYPE)
      else
        body_content =  encode_body(body, request_headers[CONTENT_TYPE])
        request_headers.merge!('Content-Length' => body_content.bytesize)
      end

      uri = URI.parse(path)
      host_options = {}

      if uri.host
        host_options[:host]   = uri.host
        host_options[:port]   = uri.port
        host_options[:scheme] = uri.scheme
        path                  = uri.request_uri
      else
        host_options[:host] = host if host
        host_options[:port] = port if port
      end

      request_options = {
          method: http_method,
          expects: Array(expects),
          path: path_with_prefix(path),
          headers: request_headers,
          body: body_content,
          query: query
      }.merge(host_options)

      request_options.merge!(response_block: response_block) if response_block

      # Store the response into client.last_response
      @last_response = http_client.request(request_options)

      parse_response(@last_response)
    rescue Excon::Errors::Unauthorized
      if token
        logger.debug 'Server reports access token expired'

        if retried || !token || !token['refresh_token']
          raise Kontena::Errors::StandardError.new(401, 'The access token has expired and needs to be refreshed')
        end

        retried = true
        retry if refresh_token
      end
      raise Kontena::Errors::StandardError.new(401, 'Unauthorized')
    rescue Excon::Errors::HTTPStatusError => error
      logger.debug "Request #{error.request[:method].upcase} #{error.request[:path]}: #{error.response.status} #{error.response.reason_phrase}: #{error.response.body}"

      handle_error_response(error.response)
    end

    # Build a token refresh request param hash
    #
    # @return [Hash]
    def refresh_request_params
      {
        refresh_token: token['refresh_token'],
        grant_type: 'refresh_token',
        client_id: client_id,
        client_secret: client_secret
      }
    end

    # Accessor to token's account settings
    def token_account
      return {} unless token
      if token.respond_to?(:account)
        token.account
      elsif token.kind_of?(Hash) && token['account'].kind_of?(String)
        config.find_account(token['account'])
      else
        {}
      end
    rescue => ex
      logger.debug "Access token refresh exception: #{ex.class.name} : #{ex.message}\n#{ex.backtrace.join("\n  ")}"
      false
    end

    # Perform refresh token request to auth provider.
    # Updates the client's Token object and writes changes to
    # configuration.
    #
    # @param [Boolean] use_basic_auth? When true, use basic auth authentication header
    # @return [Boolean] success?
    def refresh_token
      logger.debug "Performing token refresh"
      return false if token.nil?
      return false if token['refresh_token'].nil?
      uri = URI.parse(token_account['token_endpoint'])
      endpoint_data = { path: uri.path }
      endpoint_data[:host] = uri.host if uri.host
      endpoint_data[:port] = uri.port if uri.port

      logger.debug "Token refresh endpoint: #{endpoint_data.inspect}"

      return false unless endpoint_data[:path]

      response = request(
        {
          http_method: token_account['token_method'].downcase.to_sym,
          body: refresh_request_params,
          headers: {
            CONTENT_TYPE => token_account['token_post_content_type']
          }.merge(
            token_account['code_requires_basic_auth'] ? basic_auth_header : {}
          ),
          expects: [200, 201, 400, 401, 403],
          auth: false
        }.merge(endpoint_data)
      )

      if response && response['access_token']
        logger.debug "Got response to refresh request"
        token['access_token']  = response['access_token']
        token['refresh_token'] = response['refresh_token']
        token['expires_at'] = in_to_at(response['expires_in'])
        token.config.write if token.respond_to?(:config)
        true
      else
        logger.debug "Got null or bad response to refresh request: #{last_response.inspect}"
        false
      end
    rescue => ex
      logger.debug "Access token refresh exception: #{ex.class.name} : #{ex.message}\n#{ex.backtrace.join("\n  ")}"
      false
    end

    private

    # Returns true if the token object belongs to a master
    #
    # @return [Boolean]
    def token_is_for_master?
      token_account['name'] == 'master'
    end


    # Get prefixed request path unless path starts with /
    #
    # @param [String] path
    # @return [String]
    def path_with_prefix(path)
      path.to_s.start_with?('/') ? path : "#{path_prefix}#{path}"
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
    # @param [Excon::Response]
    # @return [Hash,String]
    def parse_response(response)
      check_version_and_warn(response.headers[X_KONTENA_VERSION])

      if response.headers[CONTENT_TYPE] =~ JSON_REGEX
        parse_json(response.body)
      else
        response.body
      end
    end

    def check_version_and_warn(server_version)
      return nil if $VERSION_WARNING_ADDED
      return nil unless server_version.to_s =~ /^\d+\.\d+\.\d+/

      unless server_version[/^(\d+\.\d+)/, 1] == Kontena::Cli::VERSION[/^(\d+\.\d+)/, 1] # Just compare x.y
        add_version_warning(server_version)
        $VERSION_WARNING_ADDED = true
      end
    end

    def add_version_warning(server_version)
      at_exit do
        warn Kontena.pastel.yellow("Warning: Server version is #{server_version}. You are using CLI version #{Kontena::Cli::VERSION}.")
      end
    end

    # Parse json
    #
    # @param [String] json
    # @return [Hash,Object,NilClass]
    def parse_json(json)
      JSON.parse(json)
    rescue => ex
      logger.debug "JSON parse exception: #{ex.class.name} : #{ex.message}"
      nil
    end

    # Dump json
    #
    # @param [Object] obj
    # @return [String]
    def dump_json(obj)
      JSON.dump(obj)
    end

    # @return [Boolean]
    def ignore_ssl_errors?
      ENV['SSL_IGNORE_ERRORS'] == 'true' || options[:ignore_ssl_errors]
    end

    # @param [Excon::Response] response
    def handle_error_response(response)
      data = parse_response(response)

      if data.is_a?(Hash) && data.has_key?('error') && data['error'].is_a?(Hash)
        raise Kontena::Errors::StandardErrorHash.new(response.status, response.reason_phrase, data['error'])
      elsif data.is_a?(Hash) && data.has_key?('error')
        raise Kontena::Errors::StandardError.new(response.status, data['error'])
      elsif data.is_a?(String) && !data.empty?
        raise Kontena::Errors::StandardError.new(response.status, data)
      else
        raise Kontena::Errors::StandardError.new(response.status, response.reason_phrase)
      end
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
