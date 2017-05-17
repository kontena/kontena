require 'kontena/client'

module Kontena
  class StacksClient < Client

    ACCEPT_JSON = { 'Accept' => 'application/json' }
    ACCEPT_YAML = { 'Accept' => 'application/yaml' }
    CT_YAML     = { 'Content-Type' => 'application/yaml' }

    def raise_unless_token
      unless token && token['access_token']
        raise Kontena::Errors::StandardError.new(401, "Stack registry write operations require authentication")
      end
    end

    def raise_unless_read_token
      return false unless options[:read_requires_token]
      unless token && token['access_token']
        raise Kontena::Errors::StandardError.new(401, "Stack registry requires authentication")
      end
    end

    def full_uri(stack_name, version = nil)
      URI.join(api_url, path_to(stack_name, version)).to_s
    end

    def path_to(stack_name, version = nil)
      version ? "/stack/#{stack_name}/version/#{version}" : "/stack/#{stack_name}"
    end

    def push(stack_name, version, data)
      raise_unless_token
      post('/stack/', data, {}, CT_YAML, true)
    end

    def show(stack_name, stack_version = nil)
      raise_unless_read_token
      get("#{path_to(stack_name, stack_version)}", ACCEPT_JSON, options[:read_requires_token])
    end

    def versions(stack_name)
      raise_unless_read_token
      get("#{path_to(stack_name, nil)}/versions", ACCEPT_JSON, options[:read_requires_token])['versions']
    end

    def pull(stack_name, version = nil)
      raise_unless_read_token
      get(path_to(stack_name, version), ACCEPT_YAML, options[:read_requires_token])
    rescue StandardError => ex
      ex.message << " : #{path_to(stack_name, version)}"
      raise ex, ex.message
    end

    def search(query)
      raise_unless_read_token
      get('/search', { q: query }, ACCEPT_JSON, options[:read_requires_token])['stacks']
    end

    def destroy(stack_name, version = nil)
      raise_unless_token
      delete(path_to(stack_name, version), {})
    end
  end
end
