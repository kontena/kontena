require 'uri'

module Kontena::Cli::Master
  class CurrentCommand < Kontena::Command
    option ["--name"], :flag, "Show name only", default: false
    option ["--address"], :flag, "Show IP address or FQDN only", default: false
    option ["--url"], :flag, "Show URL only", default: false

    def execute
      master = require_current_master

      if name?
        puts master['name']
      elsif address?
        puts URI.parse(master['url']).host
      elsif url?
        puts master['url']
      else
        puts "#{master['name']} #{master['url']}"
      end
    end
  end
end
