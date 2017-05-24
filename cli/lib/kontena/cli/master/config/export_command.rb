module Kontena::Cli::Master::Config
  class ExportCommand < Kontena::Command

    include Kontena::Cli::Common

    requires_current_master
    requires_current_master_token

    banner "Reads configuration from master"

    parameter '[FILE]', "Output to file in PATH, default: STDOUT", required: false, attribute_name: :path, completion: %w(*.yml *.json)
    option ['-f', '--format'], '[FORMAT]', "Specify output format (json, yaml) (default: guess from PATH or json)", completion: %(yaml json)

    option ['--filter'], "[KEY]", "Filter keys, example: oauth2.*"

    def decorate(data)
      case self.format.downcase
      when 'json'
        require 'json'
        JSON.pretty_generate(data)
      when 'yaml', 'yml'
        require 'yaml'
        YAML.dump(data)
      else
        exit_with_error "Unknown output format '#{self.format}'"
      end
    end

    def output(content)
      self.path ? File.write(self.path, content) : puts(content)
    end

    def data
      client.get("config", self.filter ? { filter: self.filter } : nil)
    end

    def set_default_format
      self.format ||= self.path.to_s.end_with?('.yml') ? 'yaml' : 'json'
    end

    def execute
      set_default_format
      output(decorate(data))
    end
  end
end
