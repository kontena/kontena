module Kontena::Cli::Master::Vagrant
  class RestartCommand < Clamp::Command
    include Kontena::Cli::Common

    def execute
      require 'kontena/machine/vagrant'
      vagrant_path = "#{Dir.home}/.kontena/vagrant_master"
      abort("Cannot find Vagrant kontena-master".colorize(:red)) unless Dir.exist?(vagrant_path)
      Dir.chdir(vagrant_path) do
        ShellSpinner "Restarting Vagrant kontena-master " do
          Open3.popen2('vagrant reload') do |stdin, output, wait|
            while o = output.gets
              print o if ENV['DEBUG']
            end
          end
        end
      end
    end
  end
end
