module Kontena::Cli::Master
  class CurrentCommand < Kontena::Command
    include Kontena::Cli::Common

    option ["--name"], :flag, "Show name only", default: false

    def execute
      master = current_master

      if name?
        puts master['name']
      else
        puts "#{master['name']} #{master['url']}"
      end
    end
  end
end
