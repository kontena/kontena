require_relative '../common'

module Kontena::Cli::Stacks::Registry
  class PushCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Stacks::Common

    banner "Pushes (uploads) a stack to the stack registry"

    parameter "[FILE]", "Kontena stack file path", default: "kontena.yml", attribute_name: :source

    requires_current_account_token

    option '--dry-run', :flag, "Do not perform any uploading", hidden: true

    def includes_local_dependencies?(dependencies = loader.dependencies)
      return false if dependencies.nil?
      dependencies.any? { |dep| Kontena::Cli::Stacks::YAML::StackFileLoader.for(dep['stack']).origin == 'file' || includes_local_dependencies(dep['depends']) }
    end

    def includes_local_extends?
      loader.yaml.fetch('services', {}).any? { |_, svc| svc.key?('extends') && svc['extends'].key?('file') }
    end

    def execute
      exit_with_error "Can only perform push from local files" unless loader.origin == "file"
      exit_with_error "Stack file contains dependencies to local files" if includes_local_dependencies?
      exit_with_error "Stack file has services that extend from local files" if includes_local_extends?

      spinner("Pushing #{pastel.cyan(source)} to stack registry as #{loader.stack_name}") do
        unless dry_run?
          stacks_client.push(
            loader.stack_name,
            loader.content
          )
        end
      end
    end
  end
end
