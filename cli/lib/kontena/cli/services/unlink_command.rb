require_relative '../grid_options'
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

      service = client(token).get("services/#{parse_service_id(name)}")
      links = service['links'].map{|l| {name: l['grid_service_id'].split('/')[1], alias: l['alias']} }
      abort("Service is not linked to #{target.to_s}") unless links.find{|l| l[:name] == target.to_s}
      links.delete_if{|l| l[:name] == target.to_s}
      data = {links: links}
      update_service(token, name, data)
    end
  end
end
