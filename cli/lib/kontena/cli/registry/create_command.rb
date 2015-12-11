require 'shell-spinner'

module Kontena::Cli::Registry
  class CreateCommand < Clamp::Command
    include Kontena::Cli::Common

    option '--node', 'NODE', 'Node name'
    option '--auth-password', 'AUTH_PASSWORD', 'Password protect registry'
    option '--s3-access-key', 'S3_ACCESS_KEY', 'S3 access key'
    option '--s3-secret-key', 'S3_SECRET_KEY', 'S3 secret key'
    option '--s3-bucket', 'S3_BUCKET', 'S3 bucket'
    option '--s3-region', 'S3_REGION', 'S3 region', default: 'eu-west-1'
    option '--s3-encrypt', :flag, 'Encrypt S3 objects', default: false
    option '--s3-secure', :flag, 'Use secure connection in S3', default: true
    option '--azure-account-name', 'AZURE_ACCOUNT_NAME', 'Azure account name'
    option '--azure-account-key', 'AZURE_ACCOUNT_KEY', 'Azure account key'
    option '--azure-container-name', 'AZURE_CONTAINER_NAME', 'Azure container name'

    def execute
      require_api_url
      token = require_token
      preferred_node = node

      registry = client(token).get("services/#{current_grid}/registry") rescue nil
      abort('Registry already exists') if registry

      nodes = client(token).get("grids/#{current_grid}/nodes")
      if preferred_node.nil?
        node = nodes['nodes'].find{|n| n['connected']}
        abort('Cannot find any online nodes') if node.nil?
      else
        node = nodes['nodes'].find{|n| n['connected'] && n['name'] == preferred_node }
        abort('Node not found') if node.nil?
      end

      if s3_access_key || s3_secret_key
        abort('--s3-access-key is missing') if s3_access_key.nil?
        abort('--s3-secret-key is missing') if s3_secret_key.nil?
        abort('--s3-bucket is missing') if s3_bucket.nil?
        env = [
            "REGISTRY_STORAGE=s3",
            "REGISTRY_STORAGE_S3_ACCESSKEY=#{s3_access_key}",
            "REGISTRY_STORAGE_S3_SECRETKEY=#{s3_secret_key}",
            "REGISTRY_STORAGE_S3_REGION=#{s3_region}",
            "REGISTRY_STORAGE_S3_BUCKET=#{s3_bucket}",
            "REGISTRY_STORAGE_S3_ENCRYPT=#{s3_encrypt?}",
            "REGISTRY_STORAGE_S3_SECURE=#{s3_secure?}",
        ]
      elsif azure_account_name || azure_account_key
        abort('--azure-account-name is missing') if azure_account_name.nil?
        abort('--azure-account-key is missing') if azure_account_key.nil?
        abort('--azure-container-name is missing') if azure_container_name.nil?
        env = [
            "REGISTRY_STORAGE=azure",
            "REGISTRY_STORAGE_AZURE_ACCOUNTNAME=#{azure_account_name}",
            "REGISTRY_STORAGE_AZURE_ACCOUNTKEY=#{azure_account_key}",
            "REGISTRY_STORAGE_AZURE_CONTAINERNAME=#{azure_container_name}"
        ]
      else
        env = [
            "REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/registry"
        ]
      end

      env << "REGISTRY_HTTP_ADDR=0.0.0.0:80"
      env << "AUTH_PASSWORD=#{auth_password}" if auth_password

      data = {
          name: 'registry',
          stateful: true,
          image: 'kontena/registry:2.1',
          volumes: ['/registry'],
          env: env,
          affinity: ["node==#{node['name']}"]
      }
      client(token).post("grids/#{current_grid}/services", data)
      client(token).post("services/#{current_grid}/registry/deploy", {})
      ShellSpinner "Deploying registry service " do
        sleep 1 until client(token).get("services/#{current_grid}/registry")['state'] != 'deploying'
      end
      puts "Docker Registry 2.1 is now running at registry.kontena.local."
      puts "Note: OpenVPN connection is needed to establish connection to this registry. See 'kontena vpn' for details."
      puts 'Note 2: you must set "--insecure-registry 10.81.0.0/19" to your client docker daemon before you are able to push to this registry.'
    end
  end
end
