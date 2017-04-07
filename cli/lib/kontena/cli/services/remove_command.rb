require_relative 'services_helper'

module Kontena::Cli::Services
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include ServicesHelper

    parameter "NAME", "Service name"
    option "--instance", "INSTANCE", "Remove only given instance"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    banner "Remove a service"

    requires_current_master
    requires_current_master_token

    def execute
      if instance
        remove_instance
      else
        remove
      end
    end

    def remove
      confirm_command(name) unless forced?

      spinner "Removing service #{name.colorize(:cyan)} " do
        client.delete("services/#{parse_service_id(name)}")
        removed = false
        until removed == true
          sleep 1
          begin
            client.get("services/#{parse_service_id(name)}")
          rescue Kontena::Errors::StandardError => exc
            if exc.status == 404
              removed = true
            else
              raise exc
            end
          end
        end
      end
    end

    def remove_instance
      instance_name = "#{name}/#{instance}"
      confirm_command("#{name}/#{instance}") unless forced?
      service_instance = client.get("services/#{parse_service_id(name)}/instances")['instances'].find{ |i|
        i['instance_number'] == instance.to_i
      }
      exit_with_error("Instance not found") unless service_instance
      spinner "Removing service instance #{instance_name.colorize(:cyan)} " do
        client.delete("services/#{parse_service_id(name)}/instances/#{service_instance['id']}")
      end
    end
  end
end
