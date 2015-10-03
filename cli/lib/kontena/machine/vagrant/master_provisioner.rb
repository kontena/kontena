require 'fileutils'
require 'erb'
require 'open3'
require 'shell-spinner'

module Kontena
  module Machine
    module Vagrant
      class MasterProvisioner
        include RandomName

        API_URL = 'http://192.168.66.100:8080'
        attr_reader :client

        def initialize
          @client = Excon.new(API_URL)
        end

        def run!(opts)
          name = generate_name
          version = opts[:version]
          memory = opts[:memory] || 1024
          auth_server = opts[:auth_server]
          vagrant_path = "#{Dir.home}/.kontena/vagrant_master/"
          if Dir.exist?(vagrant_path)
            abort("Oops... cannot create Kontena Master! You can run only one Kontena Master with Vagrant".colorize(:red))
          end
          FileUtils.mkdir_p(vagrant_path)

          template = File.join(__dir__ , '/Vagrantfile.master.rb.erb')
          cloudinit_template = File.join(__dir__ , '/cloudinit.yml')
          vars = {
            name: name,
            version: version,
            memory: memory,
            auth_server: auth_server,
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
            ShellSpinner "Waiting for #{name.colorize(:cyan)} to start " do
              sleep 1 until master_running?
            end
            puts "Kontena Master is now running at #{API_URL}"
            puts "Use #{"kontena login #{API_URL}".colorize(:light_black)} to complete Kontena Master setup"
          end
        end

        def erb(template, vars)
          ERB.new(template).result(OpenStruct.new(vars).instance_eval { binding })
        end

        def master_running?
          client.get(path: '/').status == 200
        rescue
          false
        end

        def generate_name
          "kontena-master-#{super}-#{rand(1..99)}"
        end
      end
    end
  end
end
