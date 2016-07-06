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
      auth_response = post("#{api_url}/v1/auth", obj)
      ENV["AUTH_DEBUG"] && puts("Authclient auth response #{auth_response.inspect}")
      return nil if auth_response.nil?
#      tokeninfo_response = get(
#        "#{api_url}/tokeninfo", 
#        nil,
#        nil,
#        {
#          'Authorization' => "Bearer #{auth_response['access_token']}"
#        }
#      )
#      ENV["AUTH_DEBUG"] && puts("Authclient tokeninfo response #{tokeninfo_response.inspect}")
#      return nil if tokeninfo_response.nil?
      #auth_response.merge(tokeninfo_response)
      auth_response
    rescue
      ENV["AUTH_DEBUG"] && puts("Auth service exception: #{$!} #{$!.message}\n#{$!.backtrace}")
      nil
    end

    private

    def get(path, params={}, obj=nil, headers= {})
      request_options = {
          header: default_headers.merge(headers),
          body: JSON.dump(obj),
          query: params
      }
      handle_response(http_client.get(path, request_options))
    end

    def post(path, obj, params = {})
      request_options = {
          header: default_headers,
          body: JSON.dump(obj),
          query: params
      }
      handle_response(http_client.post(path, request_options))
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
