require 'kontena/client'

module Kontena
  class StacksClient < Client

    ACCEPT_JSON = { 'Accept' => 'application/json' }
    ACCEPT_YAML = { 'Accept' => 'application/yaml' }
    CT_YAML     = { 'Content-Type' => 'application/yaml' }

    def full_uri(stack_name, version = nil)
      URI.join(api_url, path_to(stack_name, version)).to_s
    end

    def path_to(stack_name, version = nil)
      version ? "/stack/#{stack_name}/version/#{version}" : "/stack/#{stack_name}"
    end

    def push(stack_name, version, data)
      post('/stack/', data, {}, CT_YAML)
    end

    def show(stack_name, stack_version = nil)
      get("#{path_to(stack_name, stack_version)}", {}, ACCEPT_JSON)
    end

    def versions(stack_name)
      get("#{path_to(stack_name, nil)}/versions", {}, ACCEPT_JSON)['versions']
    end

    def pull(stack_name, version = nil)
      get(path_to(stack_name, version), {}, ACCEPT_YAML)
    rescue StandardError => ex
      ex.message << " : #{path_to(stack_name, version)}"
      raise ex, ex.message
    end

    def search(query)
      get('/search', { q: query }, {}, ACCEPT_JSON)['stacks']
    end

    def destroy(stack_name, version = nil)
      delete(path_to(stack_name, version), {})
    end
  end
end
