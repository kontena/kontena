module Kontena::Cli::Master::Config
  class ImportCommand < Kontena::Command

    include Kontena::Cli::Common

    requires_current_master
    requires_current_master_token

    banner "Updates configuration from a file into Master"

    parameter '[PATH]', "Input from file in PATH (default: STDIN)", required: false

    option ['--preset'], '[NAME]', 'Load preset', hidden: true

    option ['--format'], '[FORMAT]', "Specify input format (json, yaml) (default: guess from PATH or json)"
    option ['--full'], :flag, "Perform full update, keys that are not present in the input are cleared"
    option ['-f', '--force'], :flag, "Don't ask for confirmation"


    def input_as_hash
      if self.path && self.preset
        exit_with_error "Options --preset and PATH can not be used together"
      elsif self.path
        unless File.exist?(self.path) && File.readable?(self.path)
          exit_with_error "Can not read '#{self.path}'"
        end
        File.read(self.path)
      elsif self.preset
        self.format = 'yaml'
        path = File.join(Kontena.root, 'lib/kontena/presets', "#{self.preset}.yml")
        File.read(path)
      else
        stdin_input("Enter master configuration as #{format.upcase}", :multiline)
      end
    end

    def convert(data)
      case self.format.downcase
      when 'json'
        require 'json'
        JSON.parse(data)
      when 'yaml', 'yml'
        require 'yaml'
        YAML.safe_load(data)
      else
        exit_with_error "Unknown input format '#{self.format}'"
      end
    end

    def http_method
      self.full? ? :patch : :put
    end

    def upload(data)
      confirm unless self.force?
      client.send(http_method, "config", data)
    end

    def set_default_format
      self.format ||= self.path.to_s.end_with?('.yml') ? 'yaml' : 'json'
    end

    def execute
      set_default_format
      upload(convert(input_as_hash))
    end
  end
end
