require_relative '../services/services_helper'

module Kontena::Cli::Certificate
  class AuthorizeCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Services::ServicesHelper


    parameter "DOMAIN", "Domain to authorize"

    option '--type', 'AUTHORIZATION_TYPE', 'Authorization type, either tls-sni-01 or dns-01', default: 'dns-01'
    option '--linked-service', "LINKED_SERVICE", 'A service (usually LB) where the tls-sni-01 challenge certificate is bundled to'

    def execute
      require_api_url
      token = require_token

      exit_with_error "Service link needs to be given with tls-sni-01 auth type" if self.type == 'tls-sni-01' && self.linked_service.nil?

      data = {
        domain: domain,
        authorization_type: self.type
      }
      data['linked_service'] = service_path(self.linked_service) if self.type == 'tls-sni-01'

      response = client(token).post("grids/#{current_grid}/domain_authorizations", data)

      case self.type
      when 'dns-01'
        puts "Authorization successfully created. Use the following details to create necessary validations:"
        puts "Record name: #{response.dig('challenge_opts', 'record_name')}.#{domain}"
        puts "Record type: #{response.dig('challenge_opts', 'record_type')}"
        puts "Record content: #{response.dig('challenge_opts', 'record_content')}"
      when 'tls-sni-01'
        spinner "Waiting for tls-sni-01 certificate to be deployed into #{response['linked_service'].colorize(:cyan)} " do
          deployment = client(token).get("services/#{response['linked_service']}/deploys/#{response['service_deploy_id']}")
          wait_for_deploy_to_finish(token, deployment)
        end
        puts "TLS-SNI challenge certificate is deployed, you can now request the actual certificate"
      else
        exit_with_error "Unknown authorization type: #{self.type}"
      end

    end

    def service_path(linked_service)
      unless linked_service.include?('/')
        "null/#{linked_service}"
      else
        linked_service
      end
    end
  end
end
