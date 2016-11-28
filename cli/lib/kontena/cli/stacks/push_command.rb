require_relative 'common'

module Kontena::Cli::Stacks
  class PushCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    parameter "[FILENAME]", "Stack file path"

    option ['-d', '--delete'], "[STACK]", "Delete stack or stack version from registry. Use user/stack_name or user/stack_name:version."
    option ['-f', '--force'], :flag, "Force delete"

    requires_current_account_token

    def execute

      if filename && delete
        exit_with_error 'Both FILENAME and --delete given'
      elsif delete
        unless force?
          if delete.include?(':')
            puts "About to delete #{delete} from the registry"
            confirm
          else
            puts "About to delete an entire stack and all of its versions from the registry"
            confirm_command(delete)
          end
        end
        stacks_client.destroy(delete)
        puts pastel.green("Stack #{delete} deleted successfully")
      elsif filename
        file = YAML::Reader.new(filename, skip_variables: true, replace_missing: "filler")
        stacks_client.push(file.yaml['stack'], file.yaml['version'], file.raw_content)
        puts pastel.green("Successfully pushed #{file.yaml['stack']}:#{file.yaml['version']} to Stacks registry")
      else
        exit_with_error 'FILENAME or --delete required'
      end
    end
  end
end
