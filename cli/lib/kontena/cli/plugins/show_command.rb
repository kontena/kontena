require 'kontena/plugin_manager'

module Kontena::Cli::Plugins
  class ShowCommand < Kontena::Command
    parameter 'NAME', 'Plugin name' do |name|
      "kontena-plugin-#{name}"
    end

    def execute
      require 'yaml'
      plug = Gem::Specification.find { |g| g.name == name }
      out = {}
      out[:path] = plug.gem_dir
      puts out.to_yaml
    end
  end
end
