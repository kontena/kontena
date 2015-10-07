require 'fileutils'

module Kontena
  module Machine
    module Vagrant
      class NodeDestroyer
        include RandomName

        attr_reader :client, :api_client

        # @param [Kontena::Client] api_client Kontena api client
        def initialize(api_client)
          @api_client = api_client
        end

        def run!(grid, name)
          vagrant_path = "#{Dir.home}/.kontena/#{grid}/#{name}"
          Dir.chdir(vagrant_path) do
            ShellSpinner "Terminating Vagrant machine #{name.colorize(:cyan)} " do
              Open3.popen2('vagrant destroy -f') do |stdin, output, wait|
                while o = output.gets
                  puts o if ENV['DEBUG']
                end
                if wait.value == 0
                  FileUtils.remove_entry_secure(vagrant_path)
                end
              end
            end
          end
          node = api_client.get("grids/#{grid}/nodes")['nodes'].find{|n| n['name'] == name}
          if node
            ShellSpinner "Removing node #{name.colorize(:cyan)} from grid #{grid.colorize(:cyan)} " do
              api_client.delete("grids/#{grid}/nodes/#{name}")
            end
          end
        end
      end
    end
  end
end
