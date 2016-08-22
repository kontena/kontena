require 'json'
require 'excon'
require_relative 'errors'
require_relative 'cli/version'

module Kontena
  class Client

    attr_accessor :default_headers, :path_prefix
    attr_reader :http_client

    # Initialize api client
    #
    # @param [String] api_url
    # @param [String,Hash,Kontena::Cli::Config::Token] token
    # @param [Hash] default_headers
    def initialize(api_url, token = nil, default_headers = {})
      Excon.defaults[:ssl_verify_peer] = false if ignore_ssl_errors?
      @http_client = Excon.new(api_url)
      @default_headers = {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'User-Agent' => "kontena-cli/#{Kontena::Cli::VERSION}"
      }.merge(default_headers)

      if token 
        if token.kind_of?(String)
          token = { 'access_token' => token }
        end
        @default_headers.merge!('Authorization' => "Bearer #{token}")
      end

      @api_url = api_url
      @path_prefix = '/v1/'
    end

    # Get request
    #
    # @param [String] path
    # @param [Hash,NilClass] params
    # @param [Hash] headers
    # @return [Hash]
    def get(path, params = nil, headers = {})
      response = http_client.get(
        path: request_uri(path),
        query: params,
        headers: request_headers(headers)
      )
      if response.status == 200
        parse_response(response)
      else
        handle_error_response(response)
      end
    end

    # Get request
    #
    # @param [String] path
    # @param [Lambda] response_block
    # @param [Hash,NilClass] params
    # @param [Hash] headers
    def get_stream(path, response_block, params = nil, headers = {})
      http_client.get(
        read_timeout: 360,
        path: request_uri(path),
        query: params,
        headers: request_headers(headers),
        response_block: response_block
      )
    end

    # Post request
    #
    # @param [String] path
    # @param [Object] obj
    # @param [Hash] params
    # @param [Hash] headers
    # @return [Hash]
    def post(path, obj, params = {}, headers = {})
      request_headers = request_headers(headers)
      request_options = {
          path: request_uri(path),
          headers: request_headers,
          body: encode_body(obj, request_headers['Content-Type']),
          query: params
      }

      response = http_client.post(request_options)
      if [200, 201].include?(response.status)
        parse_response(response)
      else
        handle_error_response(response)
      end
    end

    # Put request
    #
    # @param [String] path
    # @param [Object] obj
    # @param [Hash] params
    # @param [Hash] headers
    # @return [Hash]
    def put(path, obj, params = {}, headers = {})
      request_headers = request_headers(headers)
      request_options = {
          path: request_uri(path),
          headers: request_headers,
          body: encode_body(obj, request_headers['Content-Type']),
          query: params
      }

      response = http_client.put(request_options)
      if [200, 201].include?(response.status)
        parse_response(response)
      else
        handle_error_response(response)
      end
    end

    # Delete request
    #
    # @param [String] path
    # @param [Hash,String] body
    # @param [Hash] params
    # @param [Hash] headers
    # @return [Hash]
    def delete(path, body = nil, params = {}, headers = {})
      request_headers = request_headers(headers)
      request_options = {
          path: request_uri(path),
          headers: request_headers,
          body: encode_body(body, request_headers['Content-Type']),
          query: params
      }
      response = http_client.delete(request_options)
      if response.status == 200
        parse_response(response)
      else
        handle_error_response(response)
      end
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

    ##
    # Get request headers
    #
    # @param [Hash] headers
    # @return [Hash]
    def request_headers(headers = {})
      @default_headers.merge(headers)
    end

    ##
    # Encode body based on content type
    #
    # @param [Object] body
    # @param [String] content_type
    def encode_body(body, content_type)
      if content_type == 'application/json'
        dump_json(body)
      else
        body
      end
    end

    ##
    # Parse response
    #
    # @param [HTTP::Message]
    # @return [Object]
    def parse_response(response)
      if response.headers['Content-Type'].include?('application/json')
        parse_json(response.body)
      else
        response.body
      end
    end

    ##
    # Parse json
    #
    # @param [String] json
    # @return [Hash,Object,NilClass]
    def parse_json(json)
      JSON.parse(json) rescue nil
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
    def handle_error_response(response)
      message = response.body
      if response.status == 404 && message == ''
        message = 'Not found'
      end
      raise Kontena::Errors::StandardError.new(response.status, message)
    end
  end
end
