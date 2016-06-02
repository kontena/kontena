require 'excon'
require 'json'

module Kontena
  module Machine
    module Upcloud
      module UpcloudCommon

        attr_reader :username
        attr_reader :password
        
        def client
          @client ||= Excon.new(
            'https://api.upcloud.com',
            omit_default_port: true,
            user: username,
            password: password,
            headers: { "Accept-Encoding" => 'application/json' }
          )
        end

        def find_template(name)
          get('storage/template')[:storages][:storage].find{|s| s[:title].downcase.start_with?(name.downcase)}
        end
        
        def find_plan(name)
          get('plan')[:plans][:plan].find{|s| s[:name].downcase.eql?(name.downcase)}
        end

        def zone_exist?(name)
          get('zone')[:zones][:zone].map{|p| p[:id]}.include?(name)
        end

        def get_server(id)
          get("server/#{id}").fetch(:server, nil)
        end

        def api_access?
          response = get('account')
          response.kind_of?(Hash) && response.has_key?(:account)
        rescue
          false
        end

        def abort_unless_api_access
          unless api_access?
            abort('Upcloud API authentication failed. Check that API access is enabled for the user.')
          end
        end

        [:get, :post, :delete].each do |http_method|
          define_method http_method do |path, opts={}|
            response = client.send(
              http_method, 
              opts.merge(
                path: File.join('/1.2', path),
                headers: {
                  'Content-Type': 'application/json'
                }
              )
            )
            if response.body && response.body.start_with?('{')
              JSON.parse(response.body, symbolize_names: true)
            elsif response.status.to_s.start_with?('2')
              {success: true}
            else
              {error: response.status}
            end
          end
        end
      end
    end
  end
end
