
module Kontena
  module Machine
    module DigitalOcean
      class NodeProvisioner
        include RandomName

        attr_reader :client, :api_client

        # @param [Kontena::Client] api_client Kontena api client
        # @param [String] token Digital Ocean token
        def initialize(api_client, token)
          @api_client = api_client
          @client = DropletKit::Client.new(access_token: token)
        end

        def run!(opts)
          raise ArgumentError.new('Invalid ssh key') unless File.exists?(File.expand_path(opts[:ssh_key]))

          ssh_key = ssh_key(File.read(File.expand_path(opts[:ssh_key])).strip)
          raise ArgumentError.new('Ssh key does not exist in Digital Ocean') unless ssh_key

          droplet = DropletKit::Droplet.new(
            name: generate_name,
            region: opts[:region],
            image: 'docker',
            size: opts[:size],
            private_networking: true,
            user_data: user_data(opts[:master_uri], opts[:grid_token]),
            ssh_keys: [ssh_key.id]
          )
          created = client.droplets.create(droplet)
          print "DigitalOcean droplet [#{droplet.name}] provision has started, please wait ."
          until client.droplets.find(id: created.id).status == 'active' do
            print '.'
            sleep 2
          end
          puts ' done!'
          print "Waiting for node [#{droplet.name}] to register itself to master ."
          until droplet_exists_in_grid?(opts[:grid], droplet)
            print '.'
            sleep 2
          end
          puts 'done!'
        end

        def user_data(master_uri, token)
          data = <<USERDATA
#cloud-config
package_upgrade: true
write_files:
  - path: /usr/local/bin/bootstrap-agent.sh
    permissions: '0700'
    content: |
      #!/bin/sh
      export DEBIAN_FRONTEND=noninteractive
      wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
      echo deb http://dl.bintray.com/kontena/kontena-testing trusty main > /etc/apt/sources.list.d/kontena.list
      apt-get update
      echo kontena-agent kontena-agent/server_uri string %s | debconf-set-selections
      echo kontena-agent kontena-agent/grid_token string %s | debconf-set-selections
      apt-get install -q -y --force-yes kontena-agent
      restart docker

runcmd:
  - /usr/local/bin/bootstrap-agent.sh

final_message: "The system is finally up, after $UPTIME seconds"

USERDATA

          data % [master_uri, token]
        end

        def ssh_key(public_key)
          ssh_key = client.ssh_keys.all.find{|key| key.public_key == public_key}
        end

        def droplet_exists_in_grid?(grid, droplet)
          api_client.get("grids/#{grid}/nodes")['nodes'].find{|n| n['name'] == droplet.name}
        end
      end
    end
  end
end
