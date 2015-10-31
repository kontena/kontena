module Kontena::Cli::Master::Vagrant
  class StartCommand < Clamp::Command
    include Kontena::Cli::Common

    def execute
      require 'kontena/machine/vagrant'
      vagrant_path = "#{Dir.home}/.kontena/vagrant_master"
      abort("Cannot find Vagrant node kontena-master".colorize(:red)) unless Dir.exist?(vagrant_path)
      Dir.chdir(vagrant_path) do
        ShellSpinner "Starting Vagrant machine kontena-master " do
          Open3.popen2('vagrant up') do |stdin, output, wait|
            while o = output.gets
              print o if ENV['DEBUG']
            end
          end
        end
      end
    end
  end
end
