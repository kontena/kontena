module Kontena::Cli::Master
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common

    def execute
      puts '%-24s %-30s' % ['Name', 'Url']
      current_server = settings['current_server']
      settings['servers'].each do |server|
        if server['name'] == current_server
          name = "* #{server['name']}"
        else
          name = server['name']
        end
        puts '%-24s %-30s' % [name, server['url']]
      end
    end
  end
end
