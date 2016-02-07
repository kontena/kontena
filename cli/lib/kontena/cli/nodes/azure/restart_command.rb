module Kontena::Cli::Nodes::Azure
  class RestartCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "Node name"
    option "--subscription-id", "SUBSCRIPTION ID", "Azure subscription id", required: true
    option "--subscription-cert", "CERTIFICATE", "Path to Azure management certificate", attribute_name: :certificate, required: true

    def execute
      require_api_url
      require_current_grid

      require 'kontena/machine/azure'

      client = ::Azure
      client.management_certificate = certificate
      client.subscription_id        = subscription_id

      client.vm_management.initialize_external_logger(Kontena::Machine::Azure::Logger.new) # We don't want all the output
      ShellSpinner "Restarting Azure VM #{name.colorize(:cyan)} " do
        vm = client.vm_management.get_virtual_machine(name, "kontena-#{current_grid}-#{name}")
        if vm
          client.vm_management.restart_virtual_machine(name, "kontena-#{current_grid}-#{name}")
        else
          abort "\nCannot find Virtual Machine #{name.colorize(:cyan)} in Azure"
        end
      end

    end
  end
end
