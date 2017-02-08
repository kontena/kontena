module Kontena::Cli::Plugins
  module Common

    def short_name(name)
      name.sub('kontena-plugin-', '')
    end
  end
end
