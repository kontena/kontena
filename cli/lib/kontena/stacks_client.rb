require_relative 'client'

module Kontena
  class StacksClient < Client
    def push(repo_name, version, data)
      post("/v1/#{repo_name}/versions/#{version}")
    end

    def pull(repo_name, version = nil)
      get("/v1/#{repo_name}/versions/#{version || 'latest'}")['stack']
    end

    def search(query)
      get('/v1/stacks', { q: query })['stacks']
    end

    def info(repo_name, version = nil)
      get("/v1/#{repo_name}/versions/#{version || 'latest'}/meta")['meta']
    end

    def versions(repo_name)
      get("/v1/#{repo_name}/versions")['versions']
    end

    def destroy(repo_name, version = nil)
      version ? delete("/v1/#{repo_name}/versions/#{version}") : delete("/v1/#{repo_name}")
    end
  end
end
