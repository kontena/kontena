require_relative '../stacks/stacks_helper'
require 'securerandom'

module Kontena::Cli::Registry
  class CreateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Stacks::StacksHelper

    REGISTRY_VERSION = '2.6.0'

    option '--node', 'NODE', 'Node name'
    option '--s3-bucket', 'S3_BUCKET', 'S3 bucket'
    option '--s3-region', 'S3_REGION', 'S3 region', default: 'eu-west-1'
    option '--s3-encrypt', :flag, 'Encrypt S3 objects', default: false
    option '--s3-secure', :flag, 'Use secure connection in S3', default: true
    option '--s3-v4auth', :flag, 'Use v4auth on S3', default: true
    option '--azure-account-name', 'AZURE_ACCOUNT_NAME', 'Azure account name'
    option '--azure-container-name', 'AZURE_CONTAINER_NAME', 'Azure container name'

    def execute
      require_api_url
      token = require_token
      preferred_node = node
      secrets = []
      affinity = []
      stateful = true
      instances = 1

      registry = client(token).get("services/#{current_grid}/registry") rescue nil
      exit_with_error('Registry already exists') if registry

      nodes = client(token).get("grids/#{current_grid}/nodes")

      if s3_bucket
        ['REGISTRY_STORAGE_S3_ACCESSKEY', 'REGISTRY_STORAGE_S3_SECRETKEY'].each do |secret|
          exit_with_error("Secret #{secret} does not exist in the vault") unless vault_secret_exists?(secret)
        end
        env = [
            "REGISTRY_STORAGE=s3",
            "REGISTRY_STORAGE_S3_REGION=#{s3_region}",
            "REGISTRY_STORAGE_S3_BUCKET=#{s3_bucket}",
            "REGISTRY_STORAGE_S3_ENCRYPT=#{s3_encrypt?}",
            "REGISTRY_STORAGE_S3_SECURE=#{s3_secure?}",
            "REGISTRY_STORAGE_S3_V4AUTH=#{s3_v4auth?}"
        ]
        secrets = [
          {secret: 'REGISTRY_STORAGE_S3_ACCESSKEY', name: 'REGISTRY_STORAGE_S3_ACCESSKEY', type: 'env'},
          {secret: 'REGISTRY_STORAGE_S3_SECRETKEY', name: 'REGISTRY_STORAGE_S3_SECRETKEY', type: 'env'}
        ]
        stateful = false
        instances = 2 if nodes['nodes'].size > 1
      elsif azure_account_name || azure_container_name
        exit_with_error('Option --azure-account-name is missing') if azure_account_name.nil?
        exit_with_error('Option --azure-container-name is missing') if azure_container_name.nil?
        exit_with_error('Secret REGISTRY_STORAGE_AZURE_ACCOUNTKEY does not exist in the vault') unless vault_secret_exists?('REGISTRY_STORAGE_AZURE_ACCOUNTKEY')
        env = [
            "REGISTRY_STORAGE=azure",
            "REGISTRY_STORAGE_AZURE_ACCOUNTNAME=#{azure_account_name}",
            "REGISTRY_STORAGE_AZURE_CONTAINER=#{azure_container_name}"
        ]
        secrets = [
          {secret: 'REGISTRY_STORAGE_AZURE_ACCOUNTKEY', name: 'REGISTRY_STORAGE_AZURE_ACCOUNTKEY', type: 'env'}
        ]
        stateful = false
        instances = 2 if nodes['nodes'].size > 1
      else
        env = [
            "REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/registry"
        ]
        if preferred_node
          node = nodes['nodes'].find{|n| n['connected'] && n['name'] == preferred_node }
          exit_with_error('Node not found') if node.nil?
          affinity << "node==#{node['name']}"
        end
      end

      if vault_secret_exists?('REGISTRY_AUTH_PASSWORD')
        secrets << {secret: 'REGISTRY_AUTH_PASSWORD', name: 'AUTH_PASSWORD', type: 'env'}
        configure_registry_auth(vault_secret('REGISTRY_AUTH_PASSWORD'))
      end
      if vault_secret_exists?('REGISTRY_HTTP_TLS_CERTIFICATE')
        secrets << {secret: 'REGISTRY_HTTP_TLS_CERTIFICATE', name: 'REGISTRY_HTTP_TLS_CERTIFICATE', type: 'env'}
        secrets << {secret: 'REGISTRY_HTTP_TLS_KEY', name: 'REGISTRY_HTTP_TLS_KEY', type: 'env'}
        env << "REGISTRY_HTTP_ADDR=0.0.0.0:443"
      else
        env << "REGISTRY_HTTP_ADDR=0.0.0.0:80"
      end
      env << "REGISTRY_HTTP_SECRET=#{SecureRandom.hex(24)}"

      data = {
        name: 'registry',
        stack: 'kontena/registry',
        version: Kontena::Cli::VERSION,
        source: '---',
        registry: 'file://',
        expose: 'api',
        services: [
          {
            name: 'api',
            stateful: stateful,
            container_count: instances,
            image: "kontena/registry:#{REGISTRY_VERSION}",
            volumes: ['/registry'],
            env: env,
            secrets: secrets,
            affinity: affinity
          }
        ]
      }

      client(token).post("grids/#{current_grid}/stacks", data)
      deployment = client(token).post("stacks/#{current_grid}/registry/deploy", {})
      spinner "Deploying #{pastel.cyan(data[:name])} stack " do
        wait_for_deploy_to_finish(deployment)
      end
      puts "\n"
      puts "Docker Registry #{REGISTRY_VERSION} is now running at registry.#{current_grid}.kontena.local."
      puts "Note: "
      puts "  - OpenVPN connection is needed to establish connection to this registry. See http://www.kontena.io/docs/using-kontena/vpn-access for details"
      puts "  - you must set '--insecure-registry registry.#{current_grid}.kontena.local' to your client docker daemon before you are able to push to this registry"
    end

    # @param [String] name
    # @return [Boolean]
    def vault_secret_exists?(name)
      client(require_token).get("secrets/#{current_grid}/#{name}")
      true
    rescue
      false
    end

    # @param [String] name
    # @return [String]
    def vault_secret(name)
      secret = client(require_token).get("secrets/#{current_grid}/#{name}")
      secret['value']
    end

    # @param [String] password
    def configure_registry_auth(password)
      data = {
        username: 'admin',
        password: password,
        email: 'not@val.id',
        url: "http://registry.#{current_grid}.kontena.local/"
      }
      client(require_token).post("grids/#{current_grid}/external_registries", data) rescue nil
    end
  end
end
