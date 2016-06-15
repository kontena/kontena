require_relative 'client'
require_relative 'cli/token_helper'

module Kontena
  module Cli
    class MasterClient < Kontena::Client

      include TokenHelper

      attr_reader :config
      attr_reader :token

      def initialize(config)
        @config = config
        if @config['account_authentication']
          @token = Kontena.config.current_account['token']
        elsif @config['token']
          @token = @config['token']
        else
          raise Kontena::Errors::StandardError, "Authentication token required"
        end
        super @config['url']
        @default_headers['Authorization'] = "Bearer #{@token}"
      end

      def account_authentication?
        config['account_authentication']
      end

      def token_expired?
        account_authentication? && Kontena.config.token_expired?
      end

      def ping
        without_token do
          get('ping') && true
        end
      end

      def master_running?
        without_token do
          get(path: '/').status == 200
        end
      end

      def grids
        get("grids")['grids']
      rescue
        []
      end

      def nodes
        get("grids/#{current_grid}/nodes")['nodes']
      rescue
        []
      end

      def find_node(name)
        nodes.find{|n| n['name'] == name}
      end

      def node_exists_in_grid?(name)
        !find_node(name).nil?
      end

      def services
        get("grids/#{current_grid}/services")['services']
      rescue
        []
      end

      def find_service(id)
        services.find{|s| s['id'] == id}
      end

      def service_containers(id)
        service = find_service(id)
        if service
          get("services/#{service['id']}/containers")['containers']
        else
          []
        end
      rescue
        []
      end

      def containers
        services.flat_map do |service|
          service_containers(service['id'])
        end
      rescue
        []
      end

      def set_node_labels(node, labels)
        data = {labels: labels}
        put("nodes/#{node['id']}", data, {}, {'Kontena-Grid-Token' => node['grid']['token']})
      end

      def auth_ok?
        if account_authentication?
          return Kontena.account_client.auth_ok?
        elsif token
          true
        else
          raise Kontena::Errors::StandardError, "You need to log in using 'kontena login'"
        end
      end

      def handle_expiration
        if account_authentication?
          Kontena.account_client.authenticate
        else
          false
        end
      end
    end
  end
end

