require 'json'
require 'httpclient'
require_relative 'errors'
require 'kontena/cli/version'

module Kontena
  class Client

    attr_accessor :default_headers
    attr_reader :http_client

    # Initialize api client
    #
    # @param [String] api_url
    # @param [Hash] default_headers
    def initialize(api_url, default_headers = {})
      @http_client = HTTPClient.new
      @http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE if ignore_ssl_errors?
      @default_headers = {'Accept' => 'application/json', 'Content-Type' => 'application/json', 'User-Agent' => "kontena-cli/#{Kontena::Cli::VERSION}"}.merge(default_headers)
      @api_url = api_url
    end

    # Get request
    #
    # @param [String] path
    # @param [Hash,NilClass] params
    # @return [Hash]
    def get(path, params = nil, headers = {})
      response = http_client.get(request_uri(path), params, request_headers(headers))
      if response.status == 200
        parse_response(response)
      else
        handle_error_response(response)
      end
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
          header: request_headers,
          body: encode_body(obj, request_headers['Content-Type']),
          query: params
      }

      response = http_client.post(request_uri(path), request_options)
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
          header: request_headers,
          body: encode_body(obj, request_headers['Content-Type']),
          query: params
      }

      response = http_client.put(request_uri(path), request_options)
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
          header: request_headers,
          body: encode_body(body, request_headers['Content-Type']),
          query: params
      }
      response = http_client.delete(request_uri(path), request_options)
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
      "#{@api_url}/v1/#{path}"
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

    def ignore_ssl_errors?
      ENV['SSL_IGNORE_ERRORS'] == 'true'
    end

    def handle_error_response(response)
      message = response.body
      if response.status == 404 && message == ''
        message = 'Not found'
      end
      raise Kontena::Errors::StandardError.new(response.status, message)
    end
  end
end
