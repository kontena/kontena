require_relative 'services_helper'

module Kontena::Cli::Services
  class UnlinkCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"
    parameter "TARGET", "Link target service name"

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
      spinner "Unlinking #{pastel.cyan(name)} from #{pastel.cyan(target)} " do
        update_service(token, name, data)
      end
    end
  end
end
