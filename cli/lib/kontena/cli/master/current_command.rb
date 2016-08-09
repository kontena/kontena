module Kontena::Cli::Master
  class CurrentCommand < Clamp::Command
    include Kontena::Cli::Common

    option ["--name"], :flag, "Show name only", default: false

    def execute
      master = require_current_master

      if name?
        puts master['name']
      else
        puts "#{master['name']} #{master['url']}"
      end
    end
  end
end
