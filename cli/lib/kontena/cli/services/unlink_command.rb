require_relative 'services_helper'

module Kontena::Cli::Services
  class UnlinkCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "SERVICE_NAME", "Service name", attribute_name: :name
    parameter "TARGET_SERVICE_NAME", "Link target service name", completion: "SERVICE_NAME", attribute_name: :target

    def execute
      require_api_url
      token = require_token
      target_service = target
      target_service = "null/#{target_service}" unless target_service.include?('/')
      target_id = "#{current_grid}/#{target_service}"
      service = client(token).get("services/#{parse_service_id(name)}")
      links = service['links']
      unless links.find { |l| l['id'] == target_id }
        exit_with_error("Service is not linked to #{target.to_s}")
      end
      links.delete_if { |l| l['id'] == target_id }
      data = {links: links}
      spinner "Unlinking #{name.colorize(:cyan)} from #{target.colorize(:cyan)} " do
        update_service(token, name, data)
      end
    end
  end
end
