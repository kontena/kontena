require_relative '../services/services_helper'

module Kontena::Cli::Certificate
  class AuthorizeCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Services::ServicesHelper

    class DeployFailedError < StandardError; end

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
        begin
          spinner "Waiting for tls-sni-01 certificate to be deployed into #{response['linked_service'].colorize(:cyan)} " do
            wait_for_domain_auth_deployed(token, response['id'])
          end
          puts "TLS-SNI challenge certificate is deployed, you can now request the actual certificate"
        rescue DeployFailedError => exc
          exit_with_error exc.message
        end
      else
        exit_with_error "Unknown authorization type: #{self.type}"
      end

    end

    def wait_for_domain_auth_deployed(token, domain_auth_id)
      Timeout.timeout(300) {
        deployed = false
        until deployed
          sleep 1
          domain_auth = client(token).get("domain_authorizations/#{domain_auth_id}")
          deploy_status = domain_auth['service_deploy_state']
          if deploy_status == 'success'
            deployed = true
          elsif deploy_status == 'error'
            raise DeployFailedError, "Linked service deploy failed. See service events for details"
          end
        end
      }
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
