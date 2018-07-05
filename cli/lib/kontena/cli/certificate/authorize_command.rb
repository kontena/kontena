require_relative '../services/services_helper'

module Kontena::Cli::Certificate
  class AuthorizeCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Services::ServicesHelper

    class DeployFailedError < StandardError; end

    parameter "DOMAIN", "Domain to authorize"

    option '--type', 'AUTHORIZATION_TYPE', 'Authorization type, either http-01, dns-01 or tls-sni-01 (renewals only)', default: 'http-01'
    option '--linked-service', "LINKED_SERVICE", 'A service (usually LB) where the http-01/tls-sni-01 challenge is deployed to'

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def requires_linked_service?
      case type
      when 'dns-01'
        false
      when 'http-01'
        true
      when 'tls-sni-01'
        true
      else
        fail "Invalid authorization --type=#{type}"
      end
    end

    def execute
      exit_with_error "--linked-service is required with --type=#{type}" if requires_linked_service? && !self.linked_service

      data = {
        domain: domain,
        authorization_type: self.type
      }
      data[:linked_service] = service_path(self.linked_service) if self.linked_service
      retried = false

      response = nil
      retry_on_le_registration do
        response = client.post("grids/#{current_grid}/domain_authorizations", data)
      end

      case self.type
      when 'dns-01'
        puts "Authorization successfully created. Use the following details to create necessary validations:"
        puts "Record name: #{response.dig('challenge_opts', 'record_name')}.#{domain}"
        puts "Record type: #{response.dig('challenge_opts', 'record_type')}"
        puts "Record content: #{response.dig('challenge_opts', 'record_content')}"
      when 'http-01'
        domain_auth = spinner "Waiting for http-01 challenge to be deployed into #{response.dig('linked_service', 'id').colorize(:cyan)} " do
          wait_for_domain_auth_deployed(response)
        end
        if domain_auth['state'] == 'deploy_error'
          exit_with_error "Linked services deploy failed. Check service events for details"
        else
          puts "HTTP challenge is deployed, you can now request the actual certificate"
        end
      when 'tls-sni-01'
        domain_auth = spinner "Waiting for tls-sni-01 challenge to be deployed into #{response.dig('linked_service', 'id').colorize(:cyan)} " do
          wait_for_domain_auth_deployed(response)
        end
        if domain_auth['state'] == 'deploy_error'
          exit_with_error "Linked services deploy failed. Check service events for details"
        else
          puts "TLS-SNI challenge certificate is deployed, you can now request the actual certificate"
        end
      else
        exit_with_error "Unknown authorization type: #{self.type}"
      end
    end

    def wait_for_domain_auth_deployed(domain_auth)
      Timeout.timeout(300) {
        while domain_auth['status'] == 'deploying' do
          sleep 1

          domain_auth = client.get("domain_authorizations/#{domain_auth['id']}")
        end
        return domain_auth
      }
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
