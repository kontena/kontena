require_relative 'services_helper'

module Kontena::Cli::Services
  class LinkCommand < Kontena::Command
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

      service = client(token).get("services/#{parse_service_id(name)}")
      existing_targets = service['links'].map{ |l| l['id'].split('/', 2)[1] }
      if existing_targets.include?(target_service.to_s)
        exit_with_error("Service is already linked to #{target.to_s}")
      end
      links = service['links'].map{ |l|
        { name: l['id'].split('/', 2)[1], alias: l['alias'] }
      }
      links << {name: target_service.to_s, alias: target.to_s}
      links.compact!
      data = {links: links}
      spinner "Linking #{name.colorize(:cyan)} to #{target.colorize(:cyan)} " do
        update_service(token, name, data)
      end
    end
  end
end
