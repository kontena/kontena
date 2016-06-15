require_relative 'client'
require_relative 'cli/token_helper'

module Kontena
  module Cli
    class AccountClient < Kontena::Client

      include TokenHelper

      attr_reader :config

      def initialize(config)
        @config = config
        super @config['url']
      end

      def require_token
        config.require_token!
        use_token
      end

      def ping
        get('ping') && true
      end

      def register_user(email, password)
        params = {email: email, password: password}
        post('users', params)
      end

      def confirm_email(verify_token)
        params = {token: verify_token}
        post('user/email_confirm', params)
      end

      private

      def auth_ok?
        if config.token.nil? || config.refresh_token.nil?
          raise Kontena::Errors::StandardError, "You need to log in using 'kontena login'"
        end

        if config.token_expired?
          handle_expiration
        else
          true
        end
      end

      def handle_expiration
        if config.refresh_token.nil? || (expiration_retry_countdown -= 1).zero?
          raise Kontena::Errors::SessionExpired
        end

        use_auth_provider
        clear_token

        params = {
          'grant_type': 'Refresh-Token',
          'refresh_token': refresh_token
        }

        data = get('token', params)
        if data.has_key?('refresh_token')
          config.update do |cfg|
            cfg.current_master['token'] = data['token']
            cfg.current_master['refresh_token'] = data['refresh_token']
            cfg.current_master['token_expires_at'] = Time.now.utc.to_i + data['expires_in'].to_i
          end
          true
        else
          false
        end
      end
    end
  end
end
