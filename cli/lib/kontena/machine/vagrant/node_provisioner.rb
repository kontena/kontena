require 'fileutils'
require 'erb'
require 'open3'
require 'shell-spinner'

module Kontena
  module Machine
    module Vagrant
      class NodeProvisioner
        include RandomName

        attr_reader :client, :api_client

        # @param [Kontena::Client] api_client Kontena api client
        def initialize(api_client)
          @api_client = api_client
        end

        def run!(opts)
          grid = opts[:grid]
          name = opts[:name] || generate_name
          version = opts[:version]
          vagrant_path = "#{Dir.home}/.kontena/#{grid}/#{name}"
          FileUtils.mkdir_p(vagrant_path)

          template = File.join(__dir__ , '/Vagrantfile.node.rb.erb')
          cloudinit_template = File.join(__dir__ , '/cloudinit.yml')
          vars = {
            name: name,
            version: version,
            memory: opts[:memory] || 1024,
            master_uri: opts[:master_uri],
            grid_token: opts[:grid_token],
            cloudinit: "#{vagrant_path}/cloudinit.yml"
          }
          vagrant_data = erb(File.read(template), vars)
          cloudinit = erb(File.read(cloudinit_template), vars)
          File.write("#{vagrant_path}/Vagrantfile", vagrant_data)
          File.write("#{vagrant_path}/cloudinit.yml", cloudinit)
          Dir.chdir(vagrant_path) do
            ShellSpinner "Creating Vagrant machine #{name.colorize(:cyan)} " do
              Open3.popen2('vagrant box update && vagrant up') do |stdin, output, wait|
                while o = output.gets
                  print o if ENV['DEBUG']
                end
              end
            end
            ShellSpinner "Waiting for node #{name.colorize(:cyan)} join to grid #{grid.colorize(:cyan)} " do
              sleep 1 until node_exists_in_grid?(grid, name)
            end
          end
        end

        def generate_name
          "#{super}-#{rand(1..99)}"
        end

        def erb(template, vars)
          ERB.new(template).result(OpenStruct.new(vars).instance_eval { binding })
        end

        def node_exists_in_grid?(grid, name)
          api_client.get("grids/#{grid}/nodes")['nodes'].find{|n| n['name'] == name}
        end
      end
    end
  end
end
