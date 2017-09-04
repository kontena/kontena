require_relative '../common'

module Kontena::Cli::Stacks::Registry
  class PushCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Stacks::Common

    banner "Pushes (uploads) a stack to the stack registry"

    include Kontena::Cli::Stacks::Common::StackFileOrNameParam
    include Kontena::Cli::Stacks::Common::StackValuesFromOption

    requires_current_account_token

    option '--dry-run', :flag, "Do not perform any uploading", hidden: true

    def includes_local_dependencies?(dependencies = loader.dependencies)
      return false if dependencies.nil?
      dependencies.any? { |dep| Kontena::Cli::Stacks::YAML::StackFileLoader.for(dep['stack']).origin == 'file' || includes_local_dependencies(dep['depends']) }
    end

    def includes_local_extends?
      stack.fetch(:services) { {} }.any? { |svc| svc['extends'] && svc[:extends]['file'] }
    end

    def execute
      set_env_variables(stack_name, 'validate', 'validate-platform')

      exit_with_error "Stack file contains dependencies to local files" if includes_local_dependencies?
      exit_with_error "Stack file has services that extend from local files" if includes_local_extends?

      spinner("Pushing #{pastel.cyan(source)} to stacks registry as #{loader.stack_name}") do
        stacks_client.push(stack_name, loader.stack_name.version, loader.content) unless dry_run?
      end
    end
  end
end
