module Kontena::Cli::Containers
  module ContainerIdParam
    def self.included(where)
      where.parameter "CONTAINER_ID", "Container id" do |container_id|
        if container_id
          client.request(http_method: :get, path: "containers/#{current_grid}/#{container_id}", expects: [200, 404])
          if client.last_response.status == 200
            container_id
          else
            ENV["DEBUG"] && STDERR.puts("Container not found with name '#{container_id}', trying to resolve..")
            containers = Kontena.run('container list --return', returning: :result)
            unless containers.kind_of?(Hash) && containers['containers']
              ENV["DEBUG"] && STDERR.puts("Invalid response from master: #{containers.inspect}")
              exit_with_error('Invalid response from master')
            end
            targets = containers['containers'].select do |c|
              c['name'].end_with?(container_id) ||
              c['name'].end_with?(container_id + "-1") ||
              c['name'] =~ /\A\w+\-#{container_id}(?:\-\d+)/
            end.map { |c| "#{c['node']['name']}/#{c['name']}" }
            if targets.empty?
              signal_usage_error "Container not found"
            elsif targets.size == 1
              ENV["DEBUG"] && STDERR.puts("Assuming intended target to be '#{targets.first}'")
              targets.first
            elsif target.size > 1
              signal_usage_error "Container not found, did you mean one of: #{targets.join(', ')}"
            end
          end
        end
      end
    end
  end
end
