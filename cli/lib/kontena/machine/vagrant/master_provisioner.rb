require 'fileutils'
require 'erb'
require 'open3'
require 'shell-spinner'

module Kontena
  module Machine
    module Vagrant
      class MasterProvisioner

        attr_reader :client

        def run!(opts)
          name = 'kontena-master'
          version = opts[:version]
          vagrant_path = "#{Dir.home}/.kontena/vagrant_master"
          FileUtils.mkdir_p(vagrant_path)

          template = File.join(__dir__ , '/Vagrantfile.master.rb.erb')
          cloudinit_template = File.join(__dir__ , '/cloudinit.yml')
          vars = {
            name: name,
            version: version,
            memory: opts[:memory] || 1024,
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
            puts "Kontena Master is now running at #{'http://192.168.66.100:8080'.colorize(:green)}"
          end
        end

        def erb(template, vars)
          ERB.new(template).result(OpenStruct.new(vars).instance_eval { binding })
        end
      end
    end
  end
end
