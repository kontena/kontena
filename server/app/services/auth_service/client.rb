require 'httpclient'
require_relative '../../mutations/access_tokens/create'

module AuthService
  class Client

    class Error < StandardError
      attr_accessor :code, :message, :backtrace

      def initialize(code, message, backtrace = nil)
        self.code = code
        self.message = message
        self.backtrace = backtrace
      end
    end

    attr_accessor :default_headers
    attr_reader :http_client

    # Initialize api client
    #
    def initialize
      @http_client = HTTPClient.new
      @http_client.ssl_config.ssl_version = :TLSv1_2
      @default_headers = {'Accept' => 'application/json', 'Content-Type' => 'application/json'}
    end

    def api_url
      AuthService.api_url
    end

    def authenticate(obj)
      response = post("#{api_url}/v1/auth", obj)

      if response.nil?
        return nil
      end
      response['user']
    end

    ##
    # @param [Hash] obj
    def register(obj)
      post("#{api_url}/v1/users", obj)
    end

    ##
    # @param [Hash] obj
    def confirm_account(obj)
      post("#{api_url}/v1/user/email_confirm", obj)
    end

    ##
    # @param [Hash] obj
    def request_password_reset(obj)
      post("#{api_url}/v1/user/password_reset", obj)
    end

    ##
    # @param [Hash] obj
    def reset_password(obj)
      put("#{api_url}/v1/user/password_reset", obj)
    end

    private

    def post(path, obj, params = {})
      request_options = {
          header: default_headers,
          body: JSON.dump(obj),
          query: params
      }
      handle_response(http_client.post(path, request_options))
    end

    def put(path, obj, params = {})
      request_options = {
          header: default_headers,
          body: JSON.dump(obj),
          query: params
      }
      handle_response(http_client.put(path, request_options))
    end

    def handle_response(response)
      if [200, 201].include?(response.status)
        JSON.parse(response.body) rescue nil
      else
        raise AuthService::Client::Error.new(response.status, response.body)
      end
    end

  end
end