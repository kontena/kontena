module Kontena
  module Cli
    module TokenHelper

      def with_token(&block)
        use_token
        yield
        clear_token
      end

      def use_token
        default_headers['Authorization'] = "Bearer #{token}"
      end

      def clear_token
        default_headers.delete('Authorization')
      end

      # Get request
      #
      # @param [String] path
      # @param [Hash,NilClass] params
      # @param [Hash] headers
      # @return [Hash]
      def get(path, params = nil, headers = {})
        auth_ok? && super
      rescue Kontena::Errors::SessionExpired => e
        handle_expiration && retry
        raise e
      end

      # Post request
      #
      # @param [String] path
      # @param [Object] obj
      # @param [Hash] params
      # @param [Hash] headers
      # @return [Hash]
      def post(path, obj, params = {}, headers = {})
        auth_ok? && super
      rescue Kontena::Errors::SessionExpired => e
        handle_expiration && retry
        raise e
      end

      # Put request
      #
      # @param [String] path
      # @param [Object] obj
      # @param [Hash] params
      # @param [Hash] headers
      # @return [Hash]
      def put(path, obj, params = {}, headers = {})
        auth_ok? && super
      rescue Kontena::Errors::SessionExpired => e
        handle_expiration && retry
        raise e
      end

      # Delete request
      #
      # @param [String] path
      # @param [Hash,String] body
      # @param [Hash] params
      # @param [Hash] headers
      # @return [Hash]
      def delete(path, body = nil, params = {}, headers = {})
        auth_ok? && super
      rescue Kontena::Errors::SessionExpired => e
        handle_expiration && retry
        raise e
      end

      def get_stream(path, response_block, params = nil, headers = {})
        auth_ok? && super
      rescue Kontena::Errors::SessionExpired => e
        handle_expiration && retry
        raise e
      end
    end
  end
end
