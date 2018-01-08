require_relative 'services_helper'

module Kontena::Cli::Services
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include ServicesHelper

    parameter "NAME ...", "Service name", attribute_name: :names
    option "--instance", "INSTANCE", "Remove only given instance"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    banner "Remove a service"

    requires_current_master
    requires_current_master_token

    def execute
      names.each do |name|
        if instance
          remove_instance(name)
        else
          remove(name)
        end
      end
    end

    def remove(name)
      confirm_command(name) unless forced?

      spinner "Removing service #{pastel.cyan(name)} " do
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

    def remove_instance(name)
      instance_name = "#{name}/#{instance}"
      confirm_command("#{name}/#{instance}") unless forced?
      service_instance = client.get("services/#{parse_service_id(name)}/instances")['instances'].find{ |i|
        i['instance_number'] == instance.to_i
      }
      exit_with_error("Instance not found") unless service_instance
      spinner "Removing service instance #{pastel.cyan(instance_name)} " do
        client.delete("services/#{parse_service_id(name)}/instances/#{service_instance['id']}")
      end
    end
  end
end
