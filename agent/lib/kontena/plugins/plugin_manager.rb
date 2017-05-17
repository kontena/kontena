module Kontena::Plugins
  class PluginManager
    include Kontena::Logging

    
    def install_plugin(name, config, alias_name = nil)
      info "starting to install plugin #{name}"
      privileges = get_privileges(name)
      pull(name, privileges, alias_name)
      set_config(name, config)
      enable_plugin(name)
      info "plugin #{name} installed succesfully"
    end

    def get_privileges(name)
      debug "getting privileges for plugin #{name}"
      Docker.connection.get("/plugins/privileges?remote=#{name}")
    end

    def pull(name, privileges, alias_name = nil)
      debug "pulling plugin #{name}"
      query = {
        'remote' => name
      }
      query['name'] = alias_name if alias_name
      Docker.connection.post('/plugins/pull', query, :body => privileges)
      debug "pulled plugin #{name}"
    end
    
    def set_config(name, config)
      Docker.connection.post("/plugins/#{name}/set", nil, :body => config.to_json)
    end

    def enable_plugin(name)
      debug "enabling plugin #{name}"
      Docker.connection.post("/plugins/#{name}/enable", {'timeout' => 10})
      debug "enabled plugin #{name}"
    end

  end
end