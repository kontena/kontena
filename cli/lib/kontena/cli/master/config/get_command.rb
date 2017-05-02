module Kontena::Cli::Master::Config
  class GetCommand < Kontena::Command

    requires_current_master
    requires_current_master_token

    banner "Reads a configuration value from master"

    parameter "KEY", "Configuration key to read from master", required: true

    option ['-p', '--pair'], :flag, "Print key=value instead of only value"

    def response
      client.get("config/#{key}")
    end

    def execute
      value = response[key]
      print(key + '=') if pair?
      puts value
    end
  end
end

