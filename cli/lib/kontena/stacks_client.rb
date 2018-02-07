require 'kontena/client'

module Kontena
  class StacksClient < Client

    ACCEPT_JSON    = { 'Accept' => 'application/json' }
    ACCEPT_YAML    = { 'Accept' => 'application/yaml' }
    ACCEPT_JSONAPI = { 'Accept' => 'application/vnd.api+json' }
    CT_YAML        = { 'Content-Type' => 'application/yaml' }
    CT_JSONAPI     = { 'Content-Type' => 'application/vnd.api+json' }

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

    def full_uri(stack_name)
      URI.join(api_url, path_to_version(stack_name)).to_s
    end

    def path_to_version(stack_name)
      path_to_stack(stack_name) + "/stack-versions/%s" % (stack_name.version || 'latest')
    end

    def path_to_stack(stack_name)
      "/v2/organizations/%s/stacks/%s" % [stack_name.user, stack_name.stack]
    end

    def push(stack_name, data)
      raise_unless_token
      post(
        '/v2/stack-files',
        {
          'data' => {
            'type' => 'stack-files',
            'attributes' => { 'content' => data }
          }
        },
        {},
        CT_JSONAPI,
        true
      )
    end

    def show(stack_name, include_prerelease: true)
      raise_unless_read_token
      result = get("#{path_to_stack(stack_name)}", { 'include' => 'latest-version', 'include-prerelease' => include_prerelease }, ACCEPT_JSONAPI)
      if result['included']
        latest = result['included'].find { |i| i['type'] == 'stack-versions' }
        return result unless latest
        result['data']['attributes']['latest-version'] = {}
        result['data']['attributes']['latest-version']['version'] = latest['attributes']['version']
        result['data']['attributes']['latest-version']['description'] = latest['attributes']['description']
        result['data']['attributes']['latest-version']['meta'] = latest['meta']
      end
      result
    end

    def versions(stack_name, include_prerelease: true, include_deleted: false)
      raise_unless_read_token
      get("#{path_to_stack(stack_name)}/stack-versions", { 'include-prerelease' => include_prerelease, 'include-deleted' => include_deleted}, ACCEPT_JSONAPI).dig('data')
    end

    def pull(stack_name)
      raise_unless_read_token
      get(path_to_version(stack_name) + '/yaml', nil, ACCEPT_YAML)
    rescue StandardError => ex
      ex.message << " : #{path_to_version(stack_name)}"
      raise ex, ex.message
    end

    def search(query, tags: [], include_prerelease: true, include_private: true, include_versionless: true)
      raise_unless_read_token
      if tags.empty?
        result = get('/v2/stacks', { 'query' => query, 'include' => 'latest-version', 'include-prerelease' => include_prerelease, 'include-private' => include_private, 'include-versionless' => include_versionless }, ACCEPT_JSONAPI)
      else
        result = get('/v2/tags/%s/stacks' % tags.join(','), { 'query' => query, 'include' => 'latest-version', 'include-prerelease' => include_prerelease, 'include-private' => include_private }, ACCEPT_JSONAPI)
      end

      data = result.dig('data')
      included = result.dig('included')
      if included
        data.each do |row|
          name = '%s/%s' % [row.fetch('attributes', {}).fetch('organization-id'), row.fetch('attributes', {}).fetch('name')]
          next if name.nil?
          included_version = included.find { |i| i.fetch('attributes', {}).fetch('name') == name }
          if included_version
            row['attributes']['latest-version'] = {}
            row['attributes']['latest-version']['version'] = included_version['attributes']['version']
            row['attributes']['latest-version']['description'] = included_version['attributes']['description']
          end
        end
      end
      data
    end

    def destroy(stack_name)
      raise_unless_token
      if stack_name.version
        id = stack_version_id(stack_name)
        if id.nil?
          raise Kontena::Errors::StandardError.new(404, 'Not found')
        end
        delete('/v2/stack-versions/%s' % id, nil, {}, ACCEPT_JSONAPI)
      else
        id = stack_id(stack_name)
        if id.nil?
          raise Kontena::Errors::StandardError.new(404, 'Not found')
        end
        delete('/v2/stacks/%s' % id, nil, {}, ACCEPT_JSONAPI)
      end
    end

    def make_private(stack_name)
      change_visibility(stack_name, is_private: true)
    end

    def make_public(stack_name)
      change_visibility(stack_name, is_private: false)
    end

    def create(stack_name, is_private: true)
      post(
        '/v2/stacks',
        stack_data(stack_name, is_private: is_private),
        {},
        CT_JSONAPI.merge(ACCEPT_JSONAPI)
      )
    end

    private

    def stack_id(stack_name)
      show(stack_name).dig('data', 'id')
    end

    def stack_version_id(stack_name)
      version = versions(stack_name, include_prerelease: true).find { |v| v.dig('attributes', 'version') == stack_name.version }
      if version
        version['id']
      else
        nil
      end
    end

    def change_visibility(stack_name, is_private: true)
      raise_unless_token
      put(
        '/v2/stacks/%s' % stack_id(stack_name),
        stack_data(stack_name, is_private: is_private),
        {},
        CT_JSONAPI.merge(ACCEPT_JSONAPI)
      )
    end

    def stack_data(stack_name, is_private: true)
      {
        data: {
          type: 'stacks',
          attributes: {
            'name' => stack_name.stack,
            'organization-id' => stack_name.user,
            'is-private' => is_private
          }
        }
      }
    end
  end
end
