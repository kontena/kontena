require_relative 'services_helper'

module Kontena::Cli::Services
  class LinkCommand < Kontena::Command
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
      spinner "Linking #{pastel.cyan(name)} to #{pastel.cyan(target)} " do
        update_service(token, name, data)
      end
    end
  end
end
