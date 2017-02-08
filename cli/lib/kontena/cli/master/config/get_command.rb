module Kontena::Cli::Master::Config
  class GetCommand < Kontena::Command

    include Kontena::Cli::Common

    requires_current_master
    requires_current_master_token

    banner "Reads a configuration value from master"

    parameter "KEY", "Configuration key to read from master", required: true

    option ['-p', '--pair'], :flag, "Print key=value instead of only value"

    option '--return', :flag, "Return the value", hidden: true

    def execute
      if self.pair?
        puts client.get("config/#{self.key}").inspect
      elsif self.return?
        return client.get("config/#{self.key}")[self.key]
      else
        puts client.get("config/#{self.key}")[self.key]
      end
    end
  end
end

