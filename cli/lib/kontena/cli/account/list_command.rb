module Kontena::Cli::Account
  class ListCommand < Clamp::Command
    include Kontena::Cli::Common

    def execute
      titles = ['NAME', 'USERNAME', 'URL']
      puts "%-20s %-40s %-50s" % titles
      Kontena.config.settings['accounts'].each do |account|
        vars = [
          account['name'],
          account['username'],
          account['url']
        ]
        puts "%-20s %-40s %-50s" % vars
      end
    end
  end
end
