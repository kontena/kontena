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
      retried = false

      response = nil
      retry_on_le_registration do
        response = client(token).post("grids/#{current_grid}/domain_authorizations", data)
      end

      case self.type
      when 'dns-01'
        puts "Authorization successfully created. Use the following details to create necessary validations:"
        puts "Record name: #{response.dig('challenge_opts', 'record_name')}.#{domain}"
        puts "Record type: #{response.dig('challenge_opts', 'record_type')}"
        puts "Record content: #{response.dig('challenge_opts', 'record_content')}"
      when 'tls-sni-01'
        state = nil
        spinner "Waiting for tls-sni-01 certificate to be deployed into #{response.dig('linked_service', 'id').colorize(:cyan)} " do
          state = wait_for_domain_auth_deployed(token, response['id'])
        end
        if state == 'deploy_error'
          puts "Linked services deploy failed. Check service events for details"
        else
          puts "TLS-SNI challenge certificate is deployed, you can now request the actual certificate"
        end
      else
        exit_with_error "Unknown authorization type: #{self.type}"
      end

    end

    def wait_for_domain_auth_deployed(token, domain_auth_id)
      state = nil
      Timeout.timeout(300) {
        sleep 1 until (state = client(token).get("domain_authorizations/#{domain_auth_id}")['status']) != 'deploying'
      }
      state
    end

    def service_path(linked_service)
      unless linked_service.include?('/')
        "null/#{linked_service}"
      else
        linked_service
      end
    end

    def retry_on_le_registration
      yield
    rescue Kontena::Errors::StandardErrorHash => exc
      raise unless exc.errors.has_key?('le_registration')
      # Run through registration
      puts "Let's Encrypt registration missing, creating one."
      email = prompt.ask("Email for Let's Encrypt:")
      Kontena.run!(['certificate', 'register', email])
      yield
    end
  end
end
