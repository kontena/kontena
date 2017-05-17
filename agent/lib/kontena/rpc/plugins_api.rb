module Kontena
  module Rpc
    class PluginsApi

      def install(name, config, alias_name)
        mgr = Kontena::Plugins::PluginManager.new
        mgr.install_plugin(name, config, alias_name)
      rescue => exc
        {error: "#{exc.class}: #{exc.message}"}
      end
    end
  end
end
