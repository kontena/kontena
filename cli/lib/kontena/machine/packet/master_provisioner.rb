require 'shell-spinner'

module Kontena
  module Machine
    module Packet
      class MasterProvisioner
        include RandomName
        include Machine::CertHelper
        include PacketCommon

        attr_reader :client, :http_client

        # @param [String] token Packet token
        def initialize(token)
          @client = login(token)
        end

        def run!(opts)
          abort('Project does not exist in Packet') unless project = find_project(opts[:project])
          abort('Facility does not exist in Packet') unless facility = find_facility(opts[:facility])
          abort('Operating system coreos_stable does not exist in Packet') unless os = find_os('coreos_stable')
          abort('Device type does not exist in Packet') unless plan = find_plan(opts[:plan])

          check_or_create_ssh_key(File.expand_path(opts[:ssh_key])) if opts[:ssh_key]

          if opts[:ssl_cert]
            abort('Invalid ssl cert') unless File.exists?(File.expand_path(opts[:ssl_cert]))
            ssl_cert = File.read(File.expand_path(opts[:ssl_cert]))
          else
            ShellSpinner "Generating self-signed SSL certificate" do
              ssl_cert = generate_self_signed_cert
            end
          end

          userdata_vars = {
            ssl_cert: ssl_cert,
            auth_server: opts[:auth_server],
            version: opts[:version],
            vault_secret: opts[:vault_secret],
            vault_iv: opts[:vault_iv],
            mongodb_uri: opts[:mongodb_uri]
          }

          device = project.new_device(
            hostname: generate_name,
            facility: facility.to_hash,
            operating_system: os.to_hash,
            plan: plan.to_hash,
            billing_cycle: opts[:billing],
            locked: true,
            userdata: user_data(userdata_vars, 'cloudinit_master.yml')
          )

          ShellSpinner "Creating Packet device #{device.hostname.colorize(:cyan)} " do
            api_retry "Packet API reported an error, please try again" do
              response = client.create_device(device)
              raise response.body unless response.success?
            end

            until device && [:active, :provisioning, :powering_on].include?(device.state)
              device = find_device(project.id, device.hostname) rescue nil
              sleep 5
            end
          end

          public_ip = device_public_ip(device)
          master_url = "https://#{public_ip['address']}"

          Excon.defaults[:ssl_verify_peer] = false
          @http_client = Excon.new("#{master_url}", :connect_timeout => 10)

          ShellSpinner "Waiting for #{device.hostname.colorize(:cyan)} to start (estimate 4 minutes)" do
            sleep 5 until master_running?
          end

          puts "Kontena Master is now running at #{master_url}"
          puts "Use #{"kontena login --name=#{device.hostname.sub('kontena-master-', '')} #{master_url}".colorize(:light_black)} to complete Kontena Master setup"
        end

        def generate_name
          "kontena-master-#{super}-#{rand(1..9)}"
        end

        def master_running?
          http_client.get(path: '/').status == 200
        rescue
          false
        end

      end
    end
  end
end
