require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Grids
  class Registry
    include Kontena::Cli::Common

    def create(opts)
      require_api_url
      token = require_token
      preferred_node = opts.node

      registry = client(token).get("services/#{current_grid}/registry") rescue nil
      raise ArgumentError.new('Registry already exists') if registry

      nodes = client(token).get("grids/#{current_grid}/nodes")
      if preferred_node.nil?
        node = nodes['nodes'].find{|n| n['connected']}
        raise ArgumentError.new('Cannot find any online nodes') if node.nil?
      else
        node = nodes['nodes'].find{|n| n['connected'] && n['name'] == preferred_node }
        raise ArgumentError.new('Node not found') if node.nil?
      end

      if opts.s3_access_key || opts.s3_secret_key
        raise ArgumentError.new('--s3-access-key is missing') if opts.s3_access_key.nil?
        raise ArgumentError.new('--s3-secret-key is missing') if opts.s3_secret_key.nil?
        raise ArgumentError.new('--s3-bucket is missing') if opts.s3_bucket.nil?
        s3_region = opts.s3_region || 'eu-west-1'
        s3_encrypt = opts.s3_encrypt || false
        s3_secure = opts.s3_secure || true
        env = [
          "REGISTRY_STORAGE=s3",
          "REGISTRY_STORAGE_S3_ACCESSKEY=#{opts.s3_access_key}",
          "REGISTRY_STORAGE_S3_SECRETKEY=#{opts.s3_secret_key}",
          "REGISTRY_STORAGE_S3_REGION=#{s3_region}",
          "REGISTRY_STORAGE_S3_BUCKET=#{opts.s3_bucket}",
          "REGISTRY_STORAGE_S3_ENCRYPT=#{s3_encrypt}",
          "REGISTRY_STORAGE_S3_SECURE=#{s3_secure}",
        ]
      elsif opts.azure_account_name || opts.azure_account_key
        raise ArgumentError.new('--azure-account-name is missing') if opts.azure_account_name.nil?
        raise ArgumentError.new('--azure-account-key is missing') if opts.azure_account_key.nil?
        raise ArgumentError.new('--azure-container-name is missing') if opts.azure_container_name.nil?
        env = [
          "REGISTRY_STORAGE=azure",
          "REGISTRY_STORAGE_AZURE_ACCOUNTNAME=#{opts.azure_account_name}",
          "REGISTRY_STORAGE_AZURE_ACCOUNTKEY=#{opts.azure_account_key}",
          "REGISTRY_STORAGE_AZURE_CONTAINERNAME=#{opts.azure_container_name}"
        ]
      else
        env = [
          "REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/registry"
        ]
      end

      env << "REGISTRY_HTTP_ADDR=0.0.0.0:80"

      data = {
        name: 'registry',
        stateful: true,
        image: 'registry:2.0',
        volumes: ['/registry'],
        env: env,
        affinity: ["node==#{node['name']}"]
      }
      client(token).post("grids/#{current_grid}/services", data)
      result = client(token).post("services/#{current_grid}/registry/deploy", {})
      print 'deploying registry service '
      until client(token).get("services/#{current_grid}/registry")['state'] != 'deploying' do
        print '.'
        sleep 1
      end
      puts ' done'
      puts "Docker Registry 2.0 is now running at registry.kontena.local."
      puts "Note: OpenVPN connection is needed to establish connection to this registry."
      puts 'Note 2: you must set "--insecure-registry 10.81.0.0/16" to your client docker daemon before you are able to push to this registry.'
    end

    def delete
      require_api_url
      token = require_token

      registry = client(token).get("services/#{current_grid}/registry") rescue nil
      raise ArgumentError.new("Docker Registry service does not exist") if registry.nil?

      client(token).delete("services/#{current_grid}/registry")
    end
  end
end
