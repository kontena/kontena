module Kontena::Cli::Nodes::Vagrant
  class StopCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "Node name"

    def execute
      require_api_url
      require_current_grid

      require 'kontena/machine/vagrant'
      vagrant_path = "#{Dir.home}/.kontena/#{current_grid}/#{name}"
      abort("Cannot find Vagrant node #{name}".colorize(:red)) unless Dir.exist?(vagrant_path)
      Dir.chdir(vagrant_path) do
          ShellSpinner "Stopping Vagrant machine #{name.colorize(:cyan)} " do
            Open3.popen2('vagrant halt') do |stdin, output, wait|
              while o = output.gets
                print o if ENV['DEBUG']
              end
            end
          end
      end
    end
  end
end
