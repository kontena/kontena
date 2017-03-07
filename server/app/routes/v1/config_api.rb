require_relative '../../mutations/audit_logs/create'

module V1
  class ConfigApi < Roda
    include RequestHelpers
    include TokenAuthenticationHelper
    include Logging

    def audit(user, key, value, request)
      task = AuditLogs::Create.run(
        user: user,
        resource_name: 'config',
        resource_type: 'config',
        resource_id: 'none',
        event_name: 'modify',
        event_status: 'success',
        event_description: "Changed value of '#{key}' to '#{value}'",
        request_parameters: {key: key, value: value},
        request_body: "{\"#{key}\" : \"#{value.inspect}\"}",
        source_ip: request.ip,
        user_agent: request.user_agent
      )
      task.success?
    end

    def audit_clear(user, request)
      task = AuditLogs::Create.run(
        user: user,
        resource_name: 'config',
        resource_type: 'config',
        resource_id: 'none',
        event_name: 'destroy_all',
        event_status: 'success',
        event_description: "Cleared configuration",
        request_parameters: {},
        request_body: "",
        source_ip: request.ip,
        user_agent: request.user_agent
      )
      task.success?
    end

    def destroy_all_and_audit(user, request)
      if audit_clear(user, request)
        Configuration.where(not: { key: 'server.salt'}).destroy_all
        true
      else
        false
      end
    end

    def update_and_audit(user, request, key, value)
      if audit(user, key, value, request)
        Configuration[key] = value
        true
      else
        false
      end
    end

    def clear_authentications
      User.each do |user|
        user.update_attribute(:external_id, nil)
      end
    end

    def update_kontena
      AuthProvider.instance.update_kontena
    end

    def is_auth_key?(key)
      key.to_s.start_with?('oauth2.') || key.to_s == 'server.root_url'
    end

    def auth_keys?(data)
      case data
      when Hash
        data.keys.any? {|k| is_auth_key?(k) }
      when Array
        data.any? {|k| is_auth_key?(k) }
      when String, Symbol
        is_auth_key?(data)
      else
        false
      end
    end

    def update_auth
      clear_authentications
      update_kontena
    end

    def update_auth_if_auth_keys(data)
      update_auth if auth_keys?(data)
    end

    def hide_salt(data)
      data.reject{ |k, _| k.to_s.eql?('server.salt') }
    end

    route do |r|
      validate_access_token('master_admin') unless current_user_admin?

      r.is do
        r.get do
          params = request.params
          if params['filter']
            if params['filter'].end_with?('*')
              regex = /^#{Regexp.escape(params['filter'].gsub(/\*/, ''))}/
            else
              regex = Regexp.new(Regexp.escape(params['filter']))
            end
            debug "Using regexp: #{regex.inspect}"
            config = Configuration.decrypt_where(key: regex)
          else
            config = Configuration.decrypt_all
          end
          response.status = 200
          hide_salt(config).sort.to_h
        end

        r.patch do
          params = parse_json_body
          params.each do |key, value|
            next if key.to_s == 'server.salt'
            unless update_and_audit(current_user, r, key, value)
              halt_request(500, 'Failed to create audit log entry') and return
            end
          end
          update_auth_if_auth_keys(params)
          response.status = 201
          {}
        end

        r.put do
          unless destroy_all_and_audit(current_user, r)
            halt_request(500, 'Failed to create audit log entry') and return
          end
          params = parse_json_body
          params.each do |key, value|
            next if key.to_s == 'server.salt'
            unless update_and_audit(current_user, r, key, value)
              halt_request(500, 'Failed to create audit log entry') and return
            end
          end
          update_auth
          response.status = 201
          {}
        end

        r.delete do
          if destroy_all_and_audit(current_user, r)
            update_auth
            response.status = 201
            {}
          else
            halt_request(500, 'Failed to create audit log entry') and return
          end
        end
      end

      r.on ':key' do |key|
        r.get do
          value = Configuration[key]
          if value.nil?
            halt_request(404, 'Not found') and return
          end
          response.status = 200
          { key => value }
        end

        r.delete do
          unless update_and_audit(current_user, r, key, nil)
            halt_request(500, 'Failed to create audit log entry') and return
          end
          update_auth_if_auth_keys(key)
          response.status = 201
          {}
        end
      end
    end
  end
end

