require_relative 'services_helper'

module Kontena::Cli::Services
  class StopCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME ...", "Service name", attribute_name: :names
    option '--[no-]wait', :flag, 'Do not wait for service to stop', default: true

    def execute
      require_api_url
      token = require_token
      names.each do |name|
        spinner "Stopping service #{pastel.cyan(name)}" do
          deployment = stop_service(token, name)
          wait_for_deploy_to_finish(deployment, vocabulary: {
              :action => "Stop",
              :ing => "Stopping",
              :ed  => "Stopped",
              :preposition => "on",
          }) if wait?
        end
      end
    end
  end
end
