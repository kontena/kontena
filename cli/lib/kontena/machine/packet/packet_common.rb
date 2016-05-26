require 'erb'

module Kontena
  module Machine
    module Packet
      module PacketCommon
        # @param [String] token Packet token
        def login(token)
          ::Packet::Client.new(token)
        end

        def create_ssh_key(ssh_key)
          client.create_ssh_key(ssh_key_label(ssh_key))
        end

        def ssh_key_exist?(ssh_key)
          client.list_ssh_keys.any?{|key| key.key == ssh_key}
        end

        def ssh_key_label(ssh_key)
          label = ssh_key[/^ssh.+?\s+\S+\s+(.*)$/, 1].to_s.strip
          label.empty? ? "kontena-ssh-key-#{rand(1..9)}" : label
        end

        # @param [String] keyfile_path Path to ssh keyfile
        def check_or_create_ssh_key(keyfile_path)
          abort('Ssh key file not found') unless File.exist?(keyfile_path)
          abort('Ssh key file not readable') unless File.readable?(keyfile_path)
          ssh_key = File.read(keyfile_path).strip
          create_ssh_key(ssh_key) unless ssh_key_exist?(ssh_key)
        end

        def find_project(project_id)
          client.list_projects.find{|project| project.id == project_id}
        end

        def find_device(project_id, device_hostname)
          client.list_devices(project_id).find{|device| device.hostname == device_hostname}
        end

        def find_facility(facility_code)
          client.list_facilities.find{|f| f.code == facility_code}
        end

        def find_os(os_code)
          client.list_operating_systems.find{|os| os.slug == os_code}
        end

        def find_plan(plan_code)
          client.list_plans.find{|plan| plan.slug == plan_code}
        end

        def device_public_ip(device)
          api_retry "Packet API did not find a public ip address for the device" do
            device.ip_addresses.find{|ip| ip['public'] && ip['address_family'] == 4}
          end
        end

        # Retry API requests to recover from random tls errors
        # @param [String] message Message to output when giving up
        # @param [Fixnum] times Default: 5
        def api_retry(message, times=5, &block)
          attempt = 1
          begin
            yield
          rescue => error
            ENV['DEBUG'] && puts("Packet API error: #{error}: #{error.message} - attempt #{attempt}")
            attempt += 1
            if attempt < times
              sleep 5 and retry
            else
              abort(message)
            end
          end
        end

        def user_data(vars, template_filename)
          cloudinit_template = File.join(__dir__ , template_filename)
          erb(File.read(cloudinit_template), vars)
        end

        def erb(template, vars)
          ERB.new(template, nil, '%<>-').result(OpenStruct.new(vars).instance_eval { binding })
        end
      end
    end
  end
end

