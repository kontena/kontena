require_relative 'client'

module Kontena
  class StacksClient < Client

    ACCEPT_JSON = { 'Accept' => 'application/json' }
    ACCEPT_YAML = { 'Accept' => 'application/yaml' }
    CT_YAML     = { 'Content-Type' => 'application/yaml' }

    def path_to(repo_name, version = nil)
      version ? "/stack/#{repo_name}/version/#{version}" : "/stack/#{repo_name}"
    end

    def push(repo_name, version, data)
      post('/stack/', data, {}, CT_YAML)
    end

    def pull(repo_name, version = nil)
      get(path_to(repo_name, version), {}, ACCEPT_YAML)
    rescue StandardError => ex
      ex.message << " : #{path_to(repo_name, version)}"
      raise ex, ex.message
    end

    def search(query)
      get('/search', { q: query }, {}, ACCEPT_JSON)
    end

    def versions(repo_name)
      get("#{path_to(repo_name)}/versions", {}, ACCEPT_JSON)
    end

    def destroy(repo_name, version = nil)
      delete(path_to(repo_name, version))
    end
  end
end
