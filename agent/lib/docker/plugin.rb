require 'docker'

module Docker
  class Plugin
    include Docker::Base

    def set(config = [])
      connection.post("/plugins/#{URI.encode(self.id)}/set", nil, :body => config.to_json)
      self
    end

    def enable
      connection.post("/plugins/#{URI.encode(id)}/enable", {'timeout' => 10})
      self
    end

    def disable
      connection.post("/plugins/#{URI.encode(id)}/disable", {'timeout' => 10})
      self
    end

    def to_s
      "Docker::Plugin { :id => #{self.id}, :connection => #{self.connection} }"
    end

    ## class methods

    # Return the container with specified ID
    def self.get(id, opts = {}, conn = Docker.connection)
      plugin_json = conn.get("/plugins/#{URI.encode(id)}/json", opts)
      hash = Docker::Util.parse_json(plugin_json) || {}
      new(conn, hash)
    end

    def self.all(opts = {}, conn = Docker.connection)
      hashes = Docker::Util.parse_json(conn.get('/plugins', opts)) || []
      hashes.map { |hash| new(conn, hash) }
    end

    def self.get_privileges(remote, opts = {}, conn = Docker.connection)
      conn.get("/plugins/privileges?remote=#{remote}")
    end

    def self.pull(name, privileges, alias_name = nil, opts = {}, conn = Docker.connection)
      query = {
        'remote' => name
      }
      query['name'] = alias_name if alias_name
      conn.post('/plugins/pull', query, :body => privileges)
    end

    def self.install_plugin(name, config, alias_name = nil)
      privileges = get_privileges(name)
      pull(name, privileges, alias_name)
      plugin = get(alias_name || name)
      set_config(alias_name || name, config)
      enable_plugin(alias_name || name)
      info "plugin #{alias_name || name} installed succesfully"
    end
  end
end