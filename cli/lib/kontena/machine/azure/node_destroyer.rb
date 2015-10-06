require 'shell-spinner'
require 'azure/virtual_machine_image_management/virtual_machine_image_management_service'

module Kontena
  module Machine
    module Azure
      class NodeDestroyer

        attr_reader :client, :api_client

        # @param [Kontena::Client] api_client Kontena api client
        # @param [String] subscription_id Azure subscription id
        # @param [String] certificate Path to Azure management certificate
        def initialize(api_client, subscription_id, certificate)
          @api_client = api_client
          abort('Invalid management certificate') unless File.exists?(File.expand_path(certificate))

          @client = ::Azure
          client.management_certificate = certificate
          client.subscription_id        = subscription_id
          client.vm_management.initialize_external_logger(Logger.new) # We don't want all the output
        end

        def run!(grid, name)
          ShellSpinner "Terminating Azure Virtual Machine #{name.colorize(:cyan)} " do
            vm = client.vm_management.get_virtual_machine(name, cloud_service_name(name, grid['name']))
            if vm
              out = StringIO.new
              $stdout = out # to avoid debug data (https://github.com/Azure/azure-sdk-for-ruby/issues/200)
              client.vm_management.delete_virtual_machine(name, cloud_service_name(name, grid['name']))
              storage_account = client.storage_management.list_storage_accounts.find{|a| a.label == cloud_service_name(name, grid['name'])}
              client.storage_management.delete_storage_account(storage_account.name) if storage_account
              $stdout = STDOUT
            else
              abort "\nCannot find Virtual Machine #{name.colorize(:cyan)} in Azure"
            end
         end

          node = api_client.get("grids/#{grid['id']}/nodes")['nodes'].find{|n| n['name'] == name}
          if node
            ShellSpinner "Removing node #{name.colorize(:cyan)} from grid #{grid['name'].colorize(:cyan)} " do
              api_client.delete("grids/#{grid['id']}/nodes/#{name}")
            end
          end
        end

        def cloud_service_name(vm_name, grid)
          "kontena-#{grid}-#{vm_name}"
        end
      end
    end
  end
end
